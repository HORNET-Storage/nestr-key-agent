package main

import (
	"context"
	"log"
	"net"
	"os"

	"golang.org/x/sys/windows/svc"
	"golang.org/x/sys/windows/svc/eventlog"
	"golang.org/x/sys/windows/svc/mgr"
	"google.golang.org/grpc"

	"github.com/HORNET-Storage/nestr-key-agent/lib/proto"
	"github.com/HORNET-Storage/nestr-key-agent/lib/service"
)

type keyAgentService struct {
	server     *grpc.Server
	stopServer context.CancelFunc
}

func (m *keyAgentService) Execute(args []string, r <-chan svc.ChangeRequest, changes chan<- svc.Status) (ssec bool, errno uint32) {
	changes <- svc.Status{State: svc.StartPending}

	// Start the key agent in background
	ctx, cancel := context.WithCancel(context.Background())
	m.stopServer = cancel

	errChan := make(chan error, 1)
	go func() {
		errChan <- m.runKeyAgent(ctx)
	}()

	changes <- svc.Status{State: svc.Running, Accepts: svc.AcceptStop | svc.AcceptShutdown}

	for {
		select {
		case c := <-r:
			switch c.Cmd {
			case svc.Interrogate:
				changes <- c.CurrentStatus
			case svc.Stop, svc.Shutdown:
				changes <- svc.Status{State: svc.StopPending}

				// Gracefully stop the server
				if m.stopServer != nil {
					m.stopServer()
				}
				if m.server != nil {
					m.server.GracefulStop()
				}

				changes <- svc.Status{State: svc.Stopped}
				return false, 0
			default:
				log.Printf("unexpected control request #%d", c)
			}
		case err := <-errChan:
			if err != nil {
				log.Printf("Key Agent error: %v", err)
				changes <- svc.Status{State: svc.Stopped}
				return true, 1
			}
			return false, 0
		}
	}
}

func (m *keyAgentService) runKeyAgent(ctx context.Context) error {
	lis, err := net.Listen("tcp", "localhost:50051")
	if err != nil {
		return err
	}

	ka := service.NewKeyAgent()
	err = ka.LoadKeyStore()
	if err != nil {
		return err
	}

	m.server = grpc.NewServer()
	proto.RegisterKeyAgentServer(m.server, ka)

	go func() {
		<-ctx.Done()
		m.server.GracefulStop()
	}()

	log.Println("Key Agent is running on localhost:50051")
	return m.server.Serve(lis)
}

func main() {
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "install":
			installService("NestrKeyAgent", "Nestr Key Agent")
			return
		case "remove":
			removeService("NestrKeyAgent")
			return
		}
	}

	err := svc.Run("NestrKeyAgent", &keyAgentService{})
	if err != nil {
		log.Fatalf("Service failed: %v", err)
	}
}

func installService(name, desc string) {
	exepath, err := os.Executable()
	if err != nil {
		log.Fatalf("Failed to get executable path: %v", err)
	}

	m, err := mgr.Connect()
	if err != nil {
		log.Fatalf("Failed to connect to service manager: %v", err)
	}
	defer m.Disconnect()

	s, err := m.CreateService(name, exepath, mgr.Config{DisplayName: desc, StartType: mgr.StartAutomatic})
	if err != nil {
		log.Fatalf("Failed to create service: %v", err)
	}
	defer s.Close()

	err = eventlog.InstallAsEventCreate(name, eventlog.Error|eventlog.Warning|eventlog.Info)
	if err != nil {
		s.Delete()
		log.Fatalf("Failed to setup event logger: %v", err)
	}
}

func removeService(name string) {
	m, err := mgr.Connect()
	if err != nil {
		log.Fatalf("Failed to connect to service manager: %v", err)
	}
	defer m.Disconnect()

	s, err := m.OpenService(name)
	if err != nil {
		log.Fatalf("Failed to open service: %v", err)
	}
	defer s.Close()

	err = s.Delete()
	if err != nil {
		log.Fatalf("Failed to delete service: %v", err)
	}

	err = eventlog.Remove(name)
	if err != nil {
		log.Fatalf("Failed to remove event logger: %v", err)
	}
}
