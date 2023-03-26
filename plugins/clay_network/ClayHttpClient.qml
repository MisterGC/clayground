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
            service[endpoint] = (...args) => {
                const buildPath = (template, params) => {
                    let index = 0;
                    return template.replace(/{\w+}/g, () => params[index++] || '');
                };
                const data = config.type === 'postJson' ? args.shift() : null;
                const url = this.baseUrl + '/' + buildPath(config.path, args);
                switch (config.type) {
                    case 'get':
                        return _webAccess.get(url);
                    case 'postJson':
                        return _webAccess.postJson(url, JSON.stringify(data));
                    default:
                        console.log(`Method '${config.type}' not supported.`);
                }
            };
        }
    }

}
