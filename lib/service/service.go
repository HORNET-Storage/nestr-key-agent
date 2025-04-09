package service

import (
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/HORNET-Storage/go-hornet-storage-lib/lib/signing"
	"github.com/HORNET-Storage/nestr-key-agent/lib/proto"

	"github.com/decred/dcrd/dcrec/secp256k1/v4"
	"golang.org/x/crypto/scrypt"
)

type KeyAgent struct {
	proto.UnimplementedKeyAgentServer
	keyStore     map[string][]byte
	keyCache     map[string]*secp256k1.PrivateKey
	cacheMutex   sync.RWMutex
	cacheTimeout time.Duration
}

func NewKeyAgent() *KeyAgent {
	return &KeyAgent{
		keyStore:     make(map[string][]byte),
		keyCache:     make(map[string]*secp256k1.PrivateKey),
		cacheTimeout: 72 * time.Hour,
	}
}

func (ka *KeyAgent) StoreKey(ctx context.Context, req *proto.StoreKeyRequest) (*proto.StoreKeyResponse, error) {
	privateKey, _, err := signing.DeserializePrivateKey(req.PrivateKey)
	if err != nil {
		return nil, fmt.Errorf("failed to deserialize private key: %v", err)
	}

	encryptedKey, err := ka.encryptKey(privateKey, req.Passphrase)
	if err != nil {
		return nil, fmt.Errorf("failed to encrypt key: %v", err)
	}

	ka.keyStore[req.KeyName] = encryptedKey
	err = ka.SaveKeyStore()
	if err != nil {
		return nil, fmt.Errorf("failed to save key store: %v", err)
	}

	return &proto.StoreKeyResponse{Success: true}, nil
}

func (ka *KeyAgent) RetrieveKey(ctx context.Context, req *proto.RetrieveKeyRequest) (*proto.RetrieveKeyResponse, error) {
	ka.cacheMutex.RLock()
	cachedKey, exists := ka.keyCache[req.KeyName]
	ka.cacheMutex.RUnlock()

	if exists {
		serializedKey, err := signing.SerializePrivateKey(cachedKey)
		if err != nil {
			return nil, fmt.Errorf("failed to serialize cached key: %v", err)
		}
		return &proto.RetrieveKeyResponse{PrivateKey: *serializedKey}, nil
	}

	encryptedKey, exists := ka.keyStore[req.KeyName]
	if !exists {
		return nil, fmt.Errorf("key not found")
	}

	privateKey, err := ka.decryptKey(encryptedKey, req.Passphrase)
	if err != nil {
		return nil, fmt.Errorf("failed to decrypt key: %v", err)
	}

	ka.cacheKey(req.KeyName, privateKey)

	serializedKey, err := signing.SerializePrivateKey(privateKey)
	if err != nil {
		return nil, fmt.Errorf("failed to serialize key: %v", err)
	}

	return &proto.RetrieveKeyResponse{PrivateKey: *serializedKey}, nil
}

func (ka *KeyAgent) cacheKey(keyName string, privateKey *secp256k1.PrivateKey) {
	ka.cacheMutex.Lock()
	defer ka.cacheMutex.Unlock()

	ka.keyCache[keyName] = privateKey
	go func() {
		time.Sleep(ka.cacheTimeout)
		ka.cacheMutex.Lock()
		delete(ka.keyCache, keyName)
		ka.cacheMutex.Unlock()
	}()
}

func (ka *KeyAgent) encryptKey(privateKey *secp256k1.PrivateKey, passphrase string) ([]byte, error) {
	keyBytes := privateKey.Serialize()

	salt := make([]byte, 8)
	_, err := io.ReadFull(rand.Reader, salt)
	if err != nil {
		return nil, err
	}

	derivedKey, err := scrypt.Key([]byte(passphrase), salt, 32768, 8, 1, 32)
	if err != nil {
		return nil, err
	}

	block, err := aes.NewCipher(derivedKey)
	if err != nil {
		return nil, err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}

	nonce := make([]byte, gcm.NonceSize())
	_, err = io.ReadFull(rand.Reader, nonce)
	if err != nil {
		return nil, err
	}

	ciphertext := gcm.Seal(nil, nonce, keyBytes, nil)
	return append(append(salt, nonce...), ciphertext...), nil
}

func (ka *KeyAgent) decryptKey(encryptedKey []byte, passphrase string) (*secp256k1.PrivateKey, error) {
	salt := encryptedKey[:8]
	nonce := encryptedKey[8:20]
	ciphertext := encryptedKey[20:]

	derivedKey, err := scrypt.Key([]byte(passphrase), salt, 32768, 8, 1, 32)
	if err != nil {
		return nil, err
	}

	block, err := aes.NewCipher(derivedKey)
	if err != nil {
		return nil, err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}

	keyBytes, err := gcm.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return nil, err
	}

	privateKey := secp256k1.PrivKeyFromBytes(keyBytes)

	return privateKey, nil
}

func (ka *KeyAgent) SaveKeyStore() error {
	data, err := json.Marshal(ka.keyStore)
	if err != nil {
		return err
	}

	home := os.Getenv("HOME")
	if home == "" {
		home = os.Getenv("USERPROFILE")
	}

	dirPath := filepath.Join(home, ".gitnestr")
	// Ensure the directory exists
	if err := os.MkdirAll(dirPath, 0700); err != nil {
		return fmt.Errorf("failed to create directory: %v", err)
	}

	keyStorePath := filepath.Join(dirPath, "keystore.json")

	return os.WriteFile(keyStorePath, data, 0600)
}

func (ka *KeyAgent) LoadKeyStore() error {
	home := os.Getenv("HOME")
	if home == "" {
		home = os.Getenv("USERPROFILE")
	}

	dirPath := filepath.Join(home, ".gitnestr")
	keyStorePath := filepath.Join(dirPath, "keystore.json")
	data, err := os.ReadFile(keyStorePath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return err
	}

	return json.Unmarshal(data, &ka.keyStore)
}
