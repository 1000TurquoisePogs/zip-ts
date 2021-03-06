/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2020
 */

const util = require('util');
const exec = util.promisify(require('child_process').exec);
const request = util.promisify(require('request'));
const expect = require('chai').expect;
const debug = require('debug')('zowe-sanity-test:api-doc-gen');

const illegalCharacterRegex = /'/gm;
const isolatedDoubleBackSlashRegex = /(?<!\\\\)\\\\(?!\\\\)/gm;
const testSuiteName = 'Generate api documentation';
const apiDefFolderPath = '../../api_definitions';
const apiDefinitionsScheme = 'https';
const apiDefinitionsMap = [
  { name: 'datasets', port: process.env.ZOWE_EXPLORER_DATASETS_PORT, swaggerJsonPath: '/v2/api-docs' },
  { name: 'jobs', port: process.env.ZOWE_EXPLORER_JOBS_PORT, swaggerJsonPath: '/v2/api-docs' },
  { name: 'gateway', port: process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT, swaggerJsonPath: '/api-doc' },
  { name: 'zlux-plugin', port: process.env.ZOWE_ZLUX_HTTPS_PORT, swaggerJsonPath: '/ZLUX/plugins/org.zowe.configjs/catalogs/swagger' }
];

describe(testSuiteName, function() {
  before('verify environment variables', function () {
    process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

    expect(process.env.SSH_HOST, 'SSH_HOST is not defined').to.not.be.empty;
    expect(process.env.ZOWE_EXPLORER_DATASETS_PORT, 'ZOWE_EXPLORER_DATASETS_PORT is not defined').to.not.be.empty;
    expect(process.env.ZOWE_EXPLORER_JOBS_PORT, 'ZOWE_EXPLORER_JOBS_PORT is not defined').to.not.be.empty;
    expect(process.env.ZOWE_ZLUX_HTTPS_PORT, 'ZOWE_ZLUX_HTTPS_PORT is not defined').to.not.be.empty;
    expect(process.env.ZOSMF_PORT, 'ZOSMF_PORT is not defined').to.not.be.empty;
    expect(process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT, 'ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT is not defined').to.not.be.empty;
  });

  it('Generate Swagger API files', async function() {
    // Acquire API definitions and store in api_definitions directory
    await createApiDefDirectory();
    await captureApiDefinitions();
  });
});

async function createApiDefDirectory() {
  debug('Create api_definitions directory.');
  await exec(`mkdir ${apiDefFolderPath}`);
}

async function captureApiDefinitions() {
  for (let apiDef of apiDefinitionsMap) {
    let url = `${apiDefinitionsScheme}://${process.env.SSH_HOST}:${apiDef.port}${apiDef.swaggerJsonPath}`;
    debug(`Capture API Swagger definition for ${apiDef.name} at ${url}`);

    let res = await request(url);
    let swaggerJsonString = res.body.replace(illegalCharacterRegex, '').replace(isolatedDoubleBackSlashRegex, '');

    await exec(`echo '${swaggerJsonString}' > ${apiDefFolderPath}/${apiDef.name}.json`);
  }
}
