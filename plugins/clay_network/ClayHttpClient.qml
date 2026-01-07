// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype ClayHttpClient
    \inqmlmodule Clayground.Network
    \brief Configurable HTTP client with automatic API method generation.

    ClayHttpClient provides a declarative way to define REST API endpoints
    and generates callable methods automatically. It supports Bearer token
    authentication and handles both GET and POST requests.

    Example usage:
    \qml
    import Clayground.Network

    ClayHttpClient {
        id: apiClient
        baseUrl: "https://api.example.com"
        endpoints: {
            "getUser": "GET users/{userId}",
            "createPost": "POST posts {postData}"
        }
        bearerToken: "your-api-token"

        onReply: (requestId, code, response) => {
            console.log("Success:", JSON.parse(response))
        }
        onError: (requestId, code, error) => {
            console.error("Error:", error)
        }

        Component.onCompleted: {
            api.getUser(123)
            api.createPost({title: "Hello", content: "World"})
        }
    }
    \endqml

    \qmlproperty string ClayHttpClient::baseUrl
    \brief Base URL for all API requests.

    All endpoint URLs are relative to this base URL.
    Example: "https://api.example.com"

    \qmlproperty var ClayHttpClient::endpoints
    \brief Object defining API endpoints.

    Each entry has the format: "{HTTP_METHOD} {urlWithParams} [{bodyName}]"
    Path parameters use {paramName} syntax.
    Example: {"getUser": "GET users/{id}", "createUser": "POST users {userData}"}

    \qmlproperty var ClayHttpClient::api
    \readonly
    \brief Generated API methods object.

    Methods are generated from the endpoints definition. Call them with
    path parameters followed by the optional body parameter.

    \qmlproperty string ClayHttpClient::bearerToken
    \brief Bearer token for authentication.

    If set, requests include an Authorization header with this token.

    \qmlsignal ClayHttpClient::reply(int requestId, int returnCode, string text)
    \brief Emitted when a request completes successfully.

    \a requestId The unique request identifier.
    \a returnCode The HTTP status code.
    \a text The response body text.

    \qmlsignal ClayHttpClient::error(int requestId, int returnCode, string text)
    \brief Emitted when a request fails.

    \a requestId The unique request identifier.
    \a returnCode The HTTP status code.
    \a text The error message or response body.
*/

import QtQuick
import Clayground.Network

Item {
    id: _clayHttpClient

    property string baseUrl: ""
    property var endpoints: ({})
    property alias api: _apiConstructor.api
    property string bearerToken: ""

    signal reply(int requestId, int returnCode, string text);
    signal error(int requestId, int returnCode, string text);

    onBaseUrlChanged: _apiConstructor.updateServiceAccess()
    onEndpointsChanged: _apiConstructor.updateServiceAccess()

    ClayWebAccess {
        id: _webAccess
        onReply:  (reqId, returnCode, result) => {
                      _clayHttpClient.reply(reqId, returnCode, result)
                  }
        onError:  (reqId, returnCode, result) => {
                      _clayHttpClient.error(reqId, returnCode, result)
                  }
    }

    QtObject
    {
        id: _apiConstructor

        // Holds the JavasScript object with methods that allow
        // convenient invocation of HTTP APIs
        property var api: ({})

        // (Re-)Generates the API object based on the service config
        function updateServiceAccess() {
            api = {};
            const authString = _formAuthString(_clayHttpClient.bearerToken);

            for (let endpoint in _clayHttpClient.endpoints) {
                const parts = _clayHttpClient.endpoints[endpoint].split(' ');
                const httpMethod = parts[0].toUpperCase();
                const endpointUrl = parts[1];
                const jsonName = parts.length > 2 ? parts[2] : "";

                // Use IIFE to create a new scope that can maintain correct values for each endpoint.
                api[endpoint] = ((endpointUrl, httpMethod, jsonName) => {
                    return function() {
                        const args = Array.prototype.slice.call(arguments);
                        const url = _constructUrl(_clayHttpClient.baseUrl, endpointUrl, args);
                        const json = jsonName !== "" && args.length ? args[args.length - 1] : "";
                        return _handleRequestMethod(httpMethod, url, json, authString);
                    };
                })(endpointUrl, httpMethod, jsonName);
            }
        }

        function _formAuthString(bearerToken) {
            return bearerToken !== "" ? `Bearer ${bearerToken}` : "";
        }

        function _constructUrl(baseUrl, endpointUrl, args) {
            let url = `${baseUrl}/${endpointUrl}`;
            url = url.replace(/\{.*?\}/g, () => args.shift());
            return url;
        }

        function _handleRequestMethod(httpMethod, url, json, authString) {
            switch (httpMethod) {
                case "GET":
                    return _webAccess.get(url, authString);
                case "POST":
                    // Convert JSON object to string if necessary
                    if (typeof json == "object" && json !== null && !Array.isArray(json))
                        json = JSON.stringify(json);
                    return _webAccess.post(url, json, authString);
            }
        }
    }

}
