import React, { Component, ErrorInfo, ReactNode } from "react";
import { Button } from "./ui/button";
import { AlertTriangle, RefreshCcw } from "lucide-react";

interface Props {
    children: ReactNode;
}

interface State {
    hasError: boolean;
    error: Error | null;
}

/**
 * Global Error Boundary to prevent the entire app from crashing.
 * In production, this should integrate with Sentry via @sentry/react.
 */
class ErrorBoundary extends Component<Props, State> {
    public state: State = {
        hasError: false,
        error: null,
    };

    public static getDerivedStateFromError(error: Error): State {
        return { hasError: true, error };
    }

    public componentDidCatch(error: Error, errorInfo: ErrorInfo) {
        console.error("Uncaught error:", error, errorInfo);
        // Integration point for Sentry:
        // Sentry.captureException(error, { extra: errorInfo });
    }

    public render() {
        if (this.state.hasError) {
            return (
                <div className="min-h-screen flex flex-col items-center justify-center p-6 bg-background text-center">
                    <div className="w-16 h-16 bg-destructive/10 rounded-full flex items-center justify-center mb-6">
                        <AlertTriangle className="text-destructive" size={32} />
                    </div>
                    <h1 className="text-2xl font-display font-bold mb-2">Something went wrong</h1>
                    <p className="text-muted-foreground max-w-md mb-8">
                        An unexpected error occurred. Our team has been notified and we're working to fix it.
                    </p>
                    <div className="flex gap-4">
                        <Button
                            variant="outline"
                            onClick={() => window.location.href = "/"}
                            className="gap-2"
                        >
                            Go to Home
                        </Button>
                        <Button
                            onClick={() => window.location.reload()}
                            className="gap-2"
                        >
                            <RefreshCcw size={16} />
                            Try Again
                        </Button>
                    </div>
                    {process.env.NODE_ENV === 'development' && (
                        <div className="mt-12 p-4 bg-secondary rounded-lg text-left max-w-2xl overflow-auto">
                            <p className="text-xs font-mono text-destructive mb-2">{this.state.error?.toString()}</p>
                        </div>
                    )}
                </div>
            );
        }

        return this.children;
    }
}

export default ErrorBoundary;
