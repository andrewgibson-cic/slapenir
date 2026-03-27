use criterion::{black_box, criterion_group, criterion_main, BenchmarkId, Criterion, Throughput};
use slapenir_proxy::sanitizer::SecretMap;
use std::collections::HashMap;

fn create_secret_map(num_secrets: usize) -> SecretMap {
    let mut secrets = HashMap::new();
    for i in 0..num_secrets {
        secrets.insert(
            format!("SECRET_{}", i),
            format!("real_secret_value_{}_with_some_extra_length", i),
        );
    }
    SecretMap::new(secrets).expect("Failed to create SecretMap")
}

fn benchmark_sanitization(c: &mut Criterion) {
    let mut group = c.benchmark_group("sanitization");

    let map = create_secret_map(10);
    let small_text = "This is a test with SECRET_0 and SECRET_1 in it.";
    let medium_text = format!("{} ", "test content with SECRET_5 embedded".repeat(100));
    let large_text = format!("{} ", "test content with SECRET_3 embedded".repeat(1000));

    group.throughput(Throughput::Bytes(small_text.len() as u64));
    group.bench_function("sanitize_small", |b| {
        b.iter(|| map.sanitize(black_box(small_text)))
    });

    group.throughput(Throughput::Bytes(medium_text.len() as u64));
    group.bench_function("sanitize_medium", |b| {
        b.iter(|| map.sanitize(black_box(&medium_text)))
    });

    group.throughput(Throughput::Bytes(large_text.len() as u64));
    group.bench_function("sanitize_large", |b| {
        b.iter(|| map.sanitize(black_box(&large_text)))
    });

    group.finish();
}

fn benchmark_injection(c: &mut Criterion) {
    let mut group = c.benchmark_group("injection");

    let map = create_secret_map(10);
    let small_text = "Replace SECRET_0 and SECRET_1 here.";
    let medium_text = format!("{} ", "Replace SECRET_5 and SECRET_6".repeat(100));
    let large_text = format!("{} ", "Replace SECRET_3 and SECRET_4".repeat(1000));

    group.throughput(Throughput::Bytes(small_text.len() as u64));
    group.bench_function("inject_small", |b| {
        b.iter(|| map.inject(black_box(small_text)))
    });

    group.throughput(Throughput::Bytes(medium_text.len() as u64));
    group.bench_function("inject_medium", |b| {
        b.iter(|| map.inject(black_box(&medium_text)))
    });

    group.throughput(Throughput::Bytes(large_text.len() as u64));
    group.bench_function("inject_large", |b| {
        b.iter(|| map.inject(black_box(&large_text)))
    });

    group.finish();
}

fn benchmark_secret_map_creation(c: &mut Criterion) {
    let mut group = c.benchmark_group("secret_map_creation");

    for size in [1, 10, 50, 100, 500].iter() {
        group.bench_with_input(BenchmarkId::from_parameter(size), size, |b, &size| {
            let mut secrets = HashMap::new();
            for i in 0..size {
                secrets.insert(format!("SECRET_{}", i), format!("value_{}", i));
            }
            b.iter(|| SecretMap::new(black_box(secrets.clone())).unwrap());
        });
    }

    group.finish();
}

fn benchmark_byte_sanitization(c: &mut Criterion) {
    let mut group = c.benchmark_group("byte_sanitization");

    let map = create_secret_map(10);
    let small_bytes: Vec<u8> = b"This is binary with SECRET_0 data.".to_vec();
    let medium_bytes: Vec<u8> = b"Binary data with SECRET_5 embedded ".repeat(100);
    let large_bytes: Vec<u8> = b"Binary data with SECRET_3 embedded ".repeat(1000);

    group.throughput(Throughput::Bytes(small_bytes.len() as u64));
    group.bench_function("sanitize_bytes_small", |b| {
        b.iter(|| map.sanitize_bytes(black_box(&small_bytes)))
    });

    group.throughput(Throughput::Bytes(medium_bytes.len() as u64));
    group.bench_function("sanitize_bytes_medium", |b| {
        b.iter(|| map.sanitize_bytes(black_box(&medium_bytes)))
    });

    group.throughput(Throughput::Bytes(large_bytes.len() as u64));
    group.bench_function("sanitize_bytes_large", |b| {
        b.iter(|| map.sanitize_bytes(black_box(&large_bytes)))
    });

    group.finish();
}

fn benchmark_no_match_path(c: &mut Criterion) {
    let mut group = c.benchmark_group("no_match_path");

    let map = create_secret_map(10);
    let text_without_secrets = "This text contains no secrets at all, just regular content.";

    group.bench_function("sanitize_no_match", |b| {
        b.iter(|| map.sanitize(black_box(text_without_secrets)))
    });

    group.bench_function("inject_no_match", |b| {
        b.iter(|| map.inject(black_box(text_without_secrets)))
    });

    group.finish();
}

fn benchmark_multiple_secrets(c: &mut Criterion) {
    let mut group = c.benchmark_group("multiple_secrets");

    for count in [1, 5, 10, 20, 50].iter() {
        group.bench_with_input(BenchmarkId::new("secrets", count), count, |b, &count| {
            let map = create_secret_map(count);
            let mut text = String::new();
            for i in 0..count {
                text.push_str(&format!("SECRET_{} ", i));
            }
            b.iter(|| map.sanitize(black_box(&text)));
        });
    }

    group.finish();
}

criterion_group! {
    name = benches;
    config = Criterion::default()
        .sample_size(100)
        .measurement_time(std::time::Duration::from_secs(5));
    targets =
        benchmark_sanitization,
        benchmark_injection,
        benchmark_secret_map_creation,
        benchmark_byte_sanitization,
        benchmark_no_match_path,
        benchmark_multiple_secrets,
}

criterion_main!(benches);
