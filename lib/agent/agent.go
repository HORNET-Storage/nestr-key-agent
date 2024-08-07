package agent

import (
	"context"
	"fmt"
	"time"

	"github.com/HORNET-Storage/nestr-key-agent/lib/proto"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

type KeyAgentClient struct {
	client proto.KeyAgentClient
	conn   *grpc.ClientConn
}

func NewKeyAgentClient() (*KeyAgentClient, error) {
	options := []grpc.DialOption{
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	}

	conn, err := grpc.NewClient("localhost:50051", options...)
	if err != nil {
		return nil, fmt.Errorf("failed to create gRPC client: %v", err)
	}

	client := proto.NewKeyAgentClient(conn)
	return &KeyAgentClient{
		client: client,
		conn:   conn,
	}, nil
}

func (c *KeyAgentClient) Close() error {
	return c.conn.Close()
}

func (c *KeyAgentClient) StoreKey(keyName, privateKey, passphrase string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	req := &proto.StoreKeyRequest{
		KeyName:    keyName,
		PrivateKey: privateKey,
		Passphrase: passphrase,
	}

	resp, err := c.client.StoreKey(ctx, req)
	if err != nil {
		return fmt.Errorf("failed to store key: %v", err)
	}

	if !resp.Success {
		return fmt.Errorf("key agent reported failure in storing key")
	}

	return nil
}

func (c *KeyAgentClient) RetrieveKey(keyName, passphrase string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	req := &proto.RetrieveKeyRequest{
		KeyName:    keyName,
		Passphrase: passphrase,
	}

	resp, err := c.client.RetrieveKey(ctx, req)
	if err != nil {
		return "", fmt.Errorf("failed to retrieve key: %v", err)
	}

	return resp.PrivateKey, nil
}
