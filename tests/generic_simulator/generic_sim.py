# Copyright 2018 Intel Corporation, Inc
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import json
import logging

import web
from web import webapi
import yaml

urls = (
  '/(.*)','MockController'
)

def setup_logger(name, log_file, level=logging.DEBUG):
    print("Configuring the logger...")
    handler = logging.FileHandler(log_file)
    formatter = logging.Formatter('%(message)s')
    handler.setFormatter(formatter)

    logger = logging.getLogger(name)
    logger.setLevel(level)
    logger.addHandler(handler)

    return logger


class MockResponse:
    def __init__(self, http_verb, status_code,
                 content_type="application/json", body="{}",
                 headers={}):
        self.http_verb = http_verb.lower()
        self.status_code = status_code
        self.content_type = content_type
        self.body = body
        self.headers = headers

def _parse_responses(parsed_responses):
    result = {}
    for path, responses in parsed_responses.iteritems():
        new_path = path
        if path.startswith("/"):
            new_path = path[1:]

        result[new_path] = []
        for http_verb, response in responses.iteritems():
            result[new_path].append(MockResponse(http_verb, **response))
    return result

def load_responses(filename):
    print("Loading responses from configuration file..")
    with open(filename) as yaml_file:
        responses_file = yaml.safe_load(yaml_file)
    responses_map = _parse_responses(responses_file)
    return responses_map


class MockController:

    def _do_action(self, action):
        logger.info('{}'.format(web.ctx.env.get('wsgi.input').read()))
        action = action.lower()
        url = web.ctx['fullpath']
        try:
            if url.startswith("/"):
                url = url[1:]
            response = [ r for r in responses_map[url] if r.http_verb == action][0]
            for header, value in response.headers.iteritems():
                web.header(header, value)
            web.header('Content-Type', response.content_type)
            print(response.body)
            return response.body
        except:
            webapi.NotFound()

    def DELETE(self, url):
        return self._do_action("delete")

    def HEAD(self, url):
        return self._do_action("head")

    def PUT(self, url):
        return self._do_action("put")

    def GET(self, url):
        return self._do_action("get")

    def POST(self, url):
        return self._do_action("post")

    def PATCH(self, url):
        return self._do_action("patch")


logger = setup_logger('mock_controller', '/tmp/generic_sim/output.log')
responses_map = load_responses('/etc/generic_sim/responses.yml')
app = web.application(urls, globals())
if __name__ == "__main__":
    app.run()
