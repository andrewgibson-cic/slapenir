// TLS Certificate Cache
// Caches generated certificates for performance with LRU eviction

use crate::tls::{CertificateAuthority, HostCertificate, TlsError};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;

/// Entry in the certificate cache with access tracking
struct CacheEntry {
    certificate: Arc<HostCertificate>,
    last_accessed: std::time::Instant,
}

/// Certificate cache with LRU eviction policy
pub struct CertificateCache {
    cache: Arc<RwLock<HashMap<String, CacheEntry>>>,
    max_capacity: usize,
}

impl CertificateCache {
    /// Default cache capacity
    const DEFAULT_CAPACITY: usize = 1000;

    /// Create a new certificate cache with default capacity
    pub fn new() -> Self {
        Self::with_capacity(Self::DEFAULT_CAPACITY)
    }

    /// Create a new certificate cache with specific capacity
    pub fn with_capacity(capacity: usize) -> Self {
        Self {
            cache: Arc::new(RwLock::new(HashMap::new())),
            max_capacity: capacity,
        }
    }

    /// Get or create a certificate for a hostname
    pub async fn get_or_create(
        &self,
        hostname: &str,
        ca: &Arc<CertificateAuthority>,
    ) -> Result<Arc<HostCertificate>, TlsError> {
        // Try to get from cache first
        {
            let mut cache = self.cache.write().await;
            if let Some(entry) = cache.get_mut(hostname) {
                // Update access time
                entry.last_accessed = std::time::Instant::now();
                return Ok(entry.certificate.clone());
            }
        }

        // Not in cache, generate new certificate
        let cert = ca.sign_for_host(hostname)?;
        let cert_arc = Arc::new(cert);

        // Store in cache
        {
            let mut cache = self.cache.write().await;

            // Check if we need to evict
            if cache.len() >= self.max_capacity {
                self.evict_lru(&mut cache);
            }

            cache.insert(
                hostname.to_string(),
                CacheEntry {
                    certificate: cert_arc.clone(),
                    last_accessed: std::time::Instant::now(),
                },
            );
        }

        Ok(cert_arc)
    }

    /// Evict the least recently used entry
    fn evict_lru(&self, cache: &mut HashMap<String, CacheEntry>) {
        if cache.is_empty() {
            return;
        }

        // Find the LRU entry
        let lru_key = cache
            .iter()
            .min_by_key(|(_, entry)| entry.last_accessed)
            .map(|(key, _)| key.clone());

        if let Some(key) = lru_key {
            cache.remove(&key);
        }
    }

    /// Get current cache size
    pub async fn len(&self) -> usize {
        self.cache.read().await.len()
    }

    /// Check if cache is empty
    pub async fn is_empty(&self) -> bool {
        self.cache.read().await.is_empty()
    }

    /// Clear all entries from cache
    pub async fn clear(&self) {
        self.cache.write().await.clear();
    }

    /// Check if a hostname is in the cache
    pub async fn contains(&self, hostname: &str) -> bool {
        self.cache.read().await.contains_key(hostname)
    }
}

impl Default for CertificateCache {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_cache_basic() {
        let ca = Arc::new(CertificateAuthority::generate().unwrap());
        let cache = CertificateCache::new();

        let cert1 = cache.get_or_create("test.com", &ca).await.unwrap();
        let cert2 = cache.get_or_create("test.com", &ca).await.unwrap();

        // Should return the same certificate (same serial)
        assert_eq!(cert1.serial(), cert2.serial());
        assert_eq!(cache.len().await, 1);
    }

    #[tokio::test]
    async fn test_cache_different_hosts() {
        let ca = Arc::new(CertificateAuthority::generate().unwrap());
        let cache = CertificateCache::new();

        let cert1 = cache.get_or_create("test1.com", &ca).await.unwrap();
        let cert2 = cache.get_or_create("test2.com", &ca).await.unwrap();

        // Should be different certificates
        assert_ne!(cert1.serial(), cert2.serial());
        assert_eq!(cache.len().await, 2);
    }

    #[tokio::test]
    async fn test_cache_lru_eviction() {
        let ca = Arc::new(CertificateAuthority::generate().unwrap());
        let cache = CertificateCache::with_capacity(3);

        // Fill cache
        cache.get_or_create("host1.com", &ca).await.unwrap();
        cache.get_or_create("host2.com", &ca).await.unwrap();
        cache.get_or_create("host3.com", &ca).await.unwrap();

        assert_eq!(cache.len().await, 3);

        // Access host1 to make it more recently used
        tokio::time::sleep(tokio::time::Duration::from_millis(10)).await;
        cache.get_or_create("host1.com", &ca).await.unwrap();

        // Add a new host, should evict host2 or host3 (whichever is LRU)
        tokio::time::sleep(tokio::time::Duration::from_millis(10)).await;
        cache.get_or_create("host4.com", &ca).await.unwrap();

        // Cache should still be at capacity
        assert_eq!(cache.len().await, 3);

        // host1 should still be in cache (was accessed recently)
        assert!(cache.contains("host1.com").await);
        // host4 should be in cache (just added)
        assert!(cache.contains("host4.com").await);
    }
}
