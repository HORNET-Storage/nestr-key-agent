package main

import (
	"log"
	"net"
	"os"
	"os/signal"
	"syscall"

	"google.golang.org/grpc"

	"github.com/HORNET-Storage/nestr-key-agent/lib/proto"
	"github.com/HORNET-Storage/nestr-key-agent/lib/service"
)

func main() {
	lis, err := net.Listen("tcp", "localhost:50051")
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	ka := service.NewKeyAgent()
	err = ka.LoadKeyStore()
	if err != nil {
		log.Fatalf("failed to load key store: %v", err)
	}

	s := grpc.NewServer()
	proto.RegisterKeyAgentServer(s, ka)

	go func() {
		log.Println("Key Agent is running on localhost:50051")
		if err := s.Serve(lis); err != nil {
			log.Fatalf("failed to serve: %v", err)
		}
	}()

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
	<-sigChan

	log.Println("Shutting down Key Agent...")
	s.GracefulStop()
}
