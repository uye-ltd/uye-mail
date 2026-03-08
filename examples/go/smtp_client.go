// Package mail provides a minimal SMTP client for sending mail through
// the uye-mail server from Go microservices.
//
// In dev:  connect to mailserver:587 (or mailpit:1025 directly)
// In prod: connect to mailserver:587 with STARTTLS
package mail

import (
	"crypto/tls"
	"fmt"
	"net/smtp"
	"strings"
)

// Config holds SMTP connection parameters.
// Populate from environment variables in your service (e.g. via os.Getenv).
type Config struct {
	// Host is the SMTP server hostname — use the Docker service name
	// ("mailserver") when running in the same Docker network.
	Host string

	// Port is typically 587 (STARTTLS submission).
	Port int

	// Username and Password are the credentials of the sending mailbox.
	Username string
	Password string

	// From is the envelope sender address.
	From string

	// InsecureSkipVerify disables TLS certificate verification.
	// Set to true in dev when using self-signed certificates.
	InsecureSkipVerify bool
}

// DefaultDevConfig returns a Config pointing at the mailserver Docker service
// with settings suitable for local development.
func DefaultDevConfig() Config {
	return Config{
		Host:               "mailserver",
		Port:               587,
		Username:           "noreply@example.com",
		Password:           "changeme",
		From:               "noreply@example.com",
		InsecureSkipVerify: true, // self-signed cert in dev
	}
}

// Message represents an outbound email.
type Message struct {
	To      []string
	Subject string
	Body    string // plain text
}

// Send delivers msg via the configured SMTP server using STARTTLS.
func Send(cfg Config, msg Message) error {
	if len(msg.To) == 0 {
		return fmt.Errorf("mail: no recipients")
	}

	auth := smtp.PlainAuth("", cfg.Username, cfg.Password, cfg.Host)
	addr := fmt.Sprintf("%s:%d", cfg.Host, cfg.Port)

	tlsCfg := &tls.Config{
		ServerName:         cfg.Host,
		InsecureSkipVerify: cfg.InsecureSkipVerify, //nolint:gosec
	}

	// Dial a plain TCP connection first, then upgrade to TLS via STARTTLS.
	conn, err := tls.Dial("tcp", addr, tlsCfg)
	if err != nil {
		// Fall back to plain + STARTTLS if direct TLS dial fails
		// (port 587 uses STARTTLS, not implicit TLS)
		return sendSTARTTLS(addr, auth, cfg, msg, tlsCfg)
	}
	defer conn.Close()

	client, err := smtp.NewClient(conn, cfg.Host)
	if err != nil {
		return fmt.Errorf("mail: smtp client: %w", err)
	}
	defer client.Close()

	return deliver(client, auth, cfg.From, msg)
}

func sendSTARTTLS(addr string, auth smtp.Auth, cfg Config, msg Message, tlsCfg *tls.Config) error {
	client, err := smtp.Dial(addr)
	if err != nil {
		return fmt.Errorf("mail: dial %s: %w", addr, err)
	}
	defer client.Close()

	if err := client.StartTLS(tlsCfg); err != nil {
		return fmt.Errorf("mail: starttls: %w", err)
	}

	return deliver(client, auth, cfg.From, msg)
}

func deliver(client *smtp.Client, auth smtp.Auth, from string, msg Message) error {
	if err := client.Auth(auth); err != nil {
		return fmt.Errorf("mail: auth: %w", err)
	}
	if err := client.Mail(from); err != nil {
		return fmt.Errorf("mail: MAIL FROM: %w", err)
	}
	for _, to := range msg.To {
		if err := client.Rcpt(to); err != nil {
			return fmt.Errorf("mail: RCPT TO %s: %w", to, err)
		}
	}

	w, err := client.Data()
	if err != nil {
		return fmt.Errorf("mail: DATA: %w", err)
	}
	defer w.Close()

	raw := buildRaw(from, msg)
	if _, err := fmt.Fprint(w, raw); err != nil {
		return fmt.Errorf("mail: write body: %w", err)
	}
	return nil
}

func buildRaw(from string, msg Message) string {
	return strings.Join([]string{
		"From: " + from,
		"To: " + strings.Join(msg.To, ", "),
		"Subject: " + msg.Subject,
		"MIME-Version: 1.0",
		"Content-Type: text/plain; charset=UTF-8",
		"",
		msg.Body,
	}, "\r\n")
}
