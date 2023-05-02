// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Network

Item {
    id: _clayHttpClient

    property string baseUrl: ""
    property var endpoints: ({})
    property var service: ({})

    signal reply(int requestId, int returnCode, string text);
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
        service = {};
        for (const [endpoint, config] of Object.entries(endpoints)) {
            accessor[endpoint] = function(...params) {
                let url = endpoints[endpoint];
                const placeholders = url.match(/\{[^\}]+\}/g);

                if (placeholders) {
                    for (const placeholder of placeholders) {
                        const param = params.shift();
                        url = url.replace(placeholder, encodeURIComponent(param));
                    }
                }
                const [method, path] = url.split(' ', 2);
                const body = params.length > 0 ? JSON.stringify(params[0]) : null;
            }
        }
    }

}
