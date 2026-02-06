// CONNECT Method Middleware
// Intercepts CONNECT requests BEFORE Axum routing to preserve upgrade capability

use axum::{
    extract::Request,
    http::Method,
    response::{IntoResponse, Response},
};
use futures::future::BoxFuture;
use std::task::{Context, Poll};
use tower::{Layer, Service};

use crate::connect::handle_connect;
use crate::middleware::AppState;

#[derive(Clone)]
pub struct ConnectLayer {
    state: AppState,
}

impl ConnectLayer {
    pub fn new(state: AppState) -> Self {
        Self { state }
    }
}

impl<S> Layer<S> for ConnectLayer {
    type Service = ConnectMiddleware<S>;

    fn layer(&self, inner: S) -> Self::Service {
        ConnectMiddleware {
            inner,
            state: self.state.clone(),
        }
    }
}

#[derive(Clone)]
pub struct ConnectMiddleware<S> {
    inner: S,
    state: AppState,
}

impl<S> Service<Request> for ConnectMiddleware<S>
where
    S: Service<Request, Response = Response> + Clone + Send + 'static,
    S::Future: Send + 'static,
{
    type Response = Response;
    type Error = S::Error;
    type Future = BoxFuture<'static, Result<Self::Response, Self::Error>>;

    fn poll_ready(&mut self, cx: &mut Context<'_>) -> Poll<Result<(), Self::Error>> {
        self.inner.poll_ready(cx)
    }

    fn call(&mut self, req: Request) -> Self::Future {
        // Check if this is a CONNECT request
        if req.method() == Method::CONNECT {
            // Handle CONNECT immediately, bypassing Axum router
            let state = self.state.clone();
            
            Box::pin(async move {
                tracing::debug!("CONNECT middleware intercepting request");
                
                match handle_connect(axum::extract::State(state), req).await {
                    Ok(response) => Ok(response),
                    Err(e) => {
                        tracing::error!("CONNECT handler error: {}", e);
                        Ok(e.into_response())
                    }
                }
            })
        } else {
            // Pass through to Axum router for non-CONNECT requests
            let future = self.inner.call(req);
            Box::pin(async move { future.await })
        }
    }
}