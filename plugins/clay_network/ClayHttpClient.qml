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
    property var api: ({})


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


    onBaseUrlChanged: _updateServiceAccess()
    onEndpointsChanged: _updateServiceAccess()

    ClayWebAccess {
        id: _webAccess
        onReply:  (reqId, returnCode, result) => {
                      _clayHttpClient.reply(reqId, returnCode, result)
                  }
        onError:  (reqId, returnCode, result) => {
                      _clayHttpClient.error(reqId, returnCode, result)
                  }
    }

    function _updateServiceAccess() {
        _clayHttpClient.api = {};

        var authString = "";
        if (_clayHttpClient.bearerToken !== "") {
            authString = "Bearer " + _clayHttpClient.bearerToken;
        }

        for (var endpoint in _clayHttpClient.endpoints) {
            var parts = _clayHttpClient.endpoints[endpoint].split(' ');
            var httpMethod = parts[0].toUpperCase();
            var endpointUrl = parts[1];
            var jsonName = parts.length > 2 ? parts[2] : "";

            // Ensure that every function has its relevant argument
            // values otherwise all would just reference the last
            // values of endpointUrl, httpMethod and jsonName
            (function(endpointUrl, httpMethod, jsonName) {
                _clayHttpClient.api[endpoint] = function() {
                    var url = _clayHttpClient.baseUrl + "/" + endpointUrl;
                    var args = Array.prototype.slice.call(arguments);
                    url = url.replace(/\{.*?\}/g, function() {
                        return args.shift();
                    });
                    switch (httpMethod) {
                        case "GET":
                            return _webAccess.get(url, authString);
                        case "POST":
                            var json = jsonName !== "" && args.length ? args[args.length - 1] : "";
                            if (typeof json == "object" && json !== null && !Array.isArray(json))
                                json = JSON.stringify(json);
                            return _webAccess.post(url, json, authString);
                    }
                }
            })(endpointUrl, httpMethod, jsonName);
        }
    }
}
