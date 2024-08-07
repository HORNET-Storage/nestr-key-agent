package main

import (
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

type keyAgentService struct{}

func (m *keyAgentService) Execute(args []string, r <-chan svc.ChangeRequest, changes chan<- svc.Status) (ssec bool, errno uint32) {
	changes <- svc.Status{State: svc.StartPending}

	go runKeyAgent()

	changes <- svc.Status{State: svc.Running, Accepts: svc.AcceptStop | svc.AcceptShutdown}

	for c := range r {
		switch c.Cmd {
		case svc.Interrogate:
			changes <- c.CurrentStatus
		case svc.Stop, svc.Shutdown:
			changes <- svc.Status{State: svc.StopPending}
			// Perform any cleanup or shutdown operations here
			return
		default:
			log.Printf("unexpected control request #%d", c)
		}
	}

	return
}

func runKeyAgent() {
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

	log.Println("Key Agent is running on localhost:50051")
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}

func main() {
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "install":
			installService("KeyAgentService", "Git Key Agent Service")
			return
		case "remove":
			removeService("KeyAgentService")
			return
		}
	}

	err := svc.Run("KeyAgentService", &keyAgentService{})
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
