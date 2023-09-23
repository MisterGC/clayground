// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Network

// Component that generates an easy to use API based on provided
// endpoint and authorization configuration.
Item {
    id: _clayHttpClient

    // END POINT CONFIGURATION

    // There is only one base URL per client
    // this allows keeping the (relative) URLs in the endpoints short
    // Example: https://acme.com/products
    property string baseUrl: ""

    // Endpoints, each entry with the following structure:
    // {HTTP_METHOD} {urlWithPathAndQueryParams} [{nameOfJsonBody}]
    // Example: GET flyingObjects/{type} {aerodynamicRequirements}
    // This will generate a method with client.api.flyingObjects("ufo", "{friction: low}"}
    property var endpoints: ({})

    // Object which contains all the methods based on the baseUrl and
    // end point configuration.
    property alias api: _apiConstructor.api


    // AUTHENTICATION/AUTHORIZATION
    // TODO Add support for basic auth and API keys

    // When using Bearer Authentication
    // Syntax: {token}
    property string bearerToken: ""


    // RESULT REPORTING

    // method has been executed successfully
    signal reply(int requestId, int returnCode, string text);

    // an error happened during execution
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
