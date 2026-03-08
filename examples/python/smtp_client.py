"""
smtp_client.py — Minimal SMTP client for sending mail from Python microservices
through the uye-mail server.

In dev:  connect to mailserver:587 (or mailpit:1025 directly)
In prod: connect to mailserver:587 with STARTTLS

Usage:
    from smtp_client import MailConfig, Message, send

    cfg = MailConfig.from_env()
    send(cfg, Message(
        to=["user@example.com"],
        subject="Hello",
        body="World",
    ))
"""

from __future__ import annotations

import os
import smtplib
import ssl
from dataclasses import dataclass
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import List, Optional


@dataclass
class MailConfig:
    # Docker service name — "mailserver" when in the same Docker network.
    host: str = "mailserver"
    port: int = 587
    username: str = ""
    password: str = ""
    from_addr: str = ""
    # Set to True in dev to skip TLS cert verification (self-signed certs).
    insecure_skip_verify: bool = False

    @classmethod
    def from_env(cls) -> "MailConfig":
        """Load config from environment variables (12-factor style)."""
        return cls(
            host=os.environ.get("SMTP_HOST", "mailserver"),
            port=int(os.environ.get("SMTP_PORT", "587")),
            username=os.environ.get("SMTP_USERNAME", ""),
            password=os.environ.get("SMTP_PASSWORD", ""),
            from_addr=os.environ.get("SMTP_FROM", ""),
            insecure_skip_verify=os.environ.get("SMTP_INSECURE", "").lower() == "true",
        )

    @classmethod
    def dev(cls) -> "MailConfig":
        """Convenience preset for local development."""
        return cls(
            host="mailserver",
            port=587,
            username="noreply@example.com",
            password="changeme",
            from_addr="noreply@example.com",
            insecure_skip_verify=True,
        )


@dataclass
class Message:
    to: List[str]
    subject: str
    body: str                        # plain text body
    html_body: Optional[str] = None  # optional HTML alternative


def send(config: MailConfig, message: Message) -> None:
    """
    Send an email via STARTTLS on port 587.
    Raises smtplib.SMTPException on failure.
    """
    if not message.to:
        raise ValueError("No recipients specified")

    msg = _build_mime(config.from_addr, message)

    ctx = ssl.create_default_context()
    if config.insecure_skip_verify:
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE

    with smtplib.SMTP(config.host, config.port, timeout=10) as server:
        server.ehlo()
        server.starttls(context=ctx)
        server.ehlo()
        if config.username:
            server.login(config.username, config.password)
        server.sendmail(config.from_addr, message.to, msg.as_string())


def _build_mime(from_addr: str, message: Message) -> MIMEMultipart | MIMEText:
    if message.html_body:
        msg: MIMEMultipart | MIMEText = MIMEMultipart("alternative")
        msg.attach(MIMEText(message.body, "plain", "utf-8"))
        msg.attach(MIMEText(message.html_body, "html", "utf-8"))
    else:
        msg = MIMEText(message.body, "plain", "utf-8")

    msg["From"] = from_addr
    msg["To"] = ", ".join(message.to)
    msg["Subject"] = message.subject
    return msg
