// SLAPENIR Strategies Module
// Organizes authentication strategy implementations

pub mod aws_sigv4;

// Re-export strategies for easier imports
pub use aws_sigv4::AWSSigV4Strategy;