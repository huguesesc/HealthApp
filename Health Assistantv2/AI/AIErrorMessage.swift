import Foundation

/// User-facing recovery messages for one-shot AI actions. Never expose response
/// bodies because providers may include sensitive request metadata.
enum AIErrorMessage {
    static func describe(_ error: Error, operation: String) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "No internet connection. Reconnect and try again."
            case .timedOut:
                return "The request timed out. Try again."
            default:
                return "The network request failed. Try again."
            }
        }

        switch error {
        case AIClientError.missingAPIKey:
            return "No Claude API key is saved. Review Coach connection in Settings."
        case let AIClientError.badResponse(statusCode, _):
            switch statusCode {
            case 401:
                return "The saved Claude API key was rejected. Review it in Settings."
            case 403:
                return "This API key is not allowed to use the requested model."
            case 404:
                return "The lightweight AI model is unavailable for this account."
            case 429:
                return "The API limit or account credit was reached. Check the Anthropic console and retry later."
            case 500...599:
                return "The AI service is temporarily unavailable. Try again shortly."
            default:
                return "The AI service returned an error (\(statusCode))."
            }
        case AIClientError.decodingFailed:
            return "The response could not be interpreted as a \(operation). Try again or enter the details manually."
        case AIClientError.notImplemented:
            return "This AI action is not available yet."
        default:
            return "The \(operation) could not be created. Try again or enter it manually."
        }
    }
}
