<?php
// =============================================================================
// Roundcube — supplementary configuration
//
// Most settings (IMAP host, SMTP host, DES key, plugins) are injected via
// environment variables in docker-compose. Only add settings here that
// cannot be expressed as environment variables.
//
// Full reference: https://github.com/roundcube/roundcubemail/wiki/Configuration
// =============================================================================

// Product branding
$config['product_name'] = 'UYE Mail';

// Managesieve — server-side mail filtering (Sieve rules via Dovecot)
$config['managesieve_host'] = 'tls://' . (getenv('ROUNDCUBEMAIL_DEFAULT_HOST') ?: 'mailserver');
$config['managesieve_port'] = 4190;
$config['managesieve_usetls'] = false; // STARTTLS is handled by the tls:// prefix

// Disable the web installer (never expose in production)
$config['enable_installer'] = false;

// Session lifetime in minutes
$config['session_lifetime'] = 60;

// Compose HTML messages by default
$config['htmleditor'] = 1;

// Automatically add read receipts
$config['mdn_requests'] = 0;

// Spell check language
$config['spellcheck_engine'] = 'googie';

// Refresh inbox every N seconds (0 = disabled, use IMAP IDLE instead)
$config['refresh_interval'] = 60;

// Default page size for message list
$config['pagesize'] = 50;
