/**
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright IBM Corporation 2018, 2019
 */

const _ = require('lodash');
const expect = require('chai').expect;
const debug = require('debug')('zowe-sanity-test:explorer:api-jobs');
const axios = require('axios');
const addContext = require('mochawesome/addContext');
const { handleCompressionRequest } = require('./zlib-helper');

const { ZOWE_JOB_NAME } = require('../constants');

let REQ, username, password;

describe('test explorer server jobs api', function() {
  before('verify environment variables', function() {
    // allow self signed certs
    process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

    expect(process.env.ZOWE_EXTERNAL_HOST, 'ZOWE_EXTERNAL_HOST is empty').to.not.be.empty;
    expect(process.env.SSH_USER, 'SSH_USER is not defined').to.not.be.empty;
    expect(process.env.SSH_PASSWD, 'SSH_PASSWD is not defined').to.not.be.empty;
    expect(process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT, 'ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT is not defined').to.not.be.empty;

    REQ = axios.create({
      baseURL: `https://${process.env.ZOWE_EXTERNAL_HOST}:${process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}`,
      timeout: 30000,
    });
    
    username = process.env.SSH_USER;
    password = process.env.SSH_PASSWD;
    debug(`Explorer server URL: https://${process.env.ZOWE_EXTERNAL_HOST}:${process.env.ZOWE_API_MEDIATION_GATEWAY_HTTP_PORT}`);
  });

  it(`should be able to list jobs and have a job ${ZOWE_JOB_NAME}`, async function() {
    const _this = this;

    const req = {
      method: 'get',
      url: '/jobs/api/v1',
      params: {
        prefix: `${ZOWE_JOB_NAME}*`,
        owner: 'ZWE*',
        status: 'ACTIVE',
      },
      auth: {
        username,
        password,
      }
    };
    debug('request', req);

    function verifyResponse(res) {
      debug('response', _.pick(res, ['status', 'statusText', 'headers', 'data']));
      addContext(_this, {
        title: 'http response',
        value: res && res.data
      });
      expect(res).to.have.property('status');
      expect(res.status).to.equal(200);
      expect(res.data.items).to.be.an('array');
      expect(res.data.items).to.have.lengthOf(1);
      expect(res.data.items[0]).to.have.any.keys('jobName', 'jobId', 'owner', 'status', 'type', 'subsystem');
      expect(res.data.items[0].jobName).to.equal(ZOWE_JOB_NAME);
    }

    debug('list jobs default');
    let res = await REQ.request(req);
    
    verifyResponse(res);

    debug('list jobs decompress with zlib');
    res = await handleCompressionRequest(REQ,req);
    verifyResponse(res);
  });

  it('returns the current user\'s TSO userid', function() {
    const _this = this;

    const req = {
      method: 'get',
      url: '/jobs/api/v1/username',
      auth: {
        username,
        password,
      }
    };
    debug('request', req);

    return REQ.request(req)
      .then(function(res) {
        debug('response', _.pick(res, ['status', 'statusText', 'headers', 'data']));
        addContext(_this, {
          title: 'http response',
          value: res && res.data
        });

        expect(res).to.have.property('status');
        expect(res.status).to.equal(200);
        expect(res.data).to.be.an('object');
        expect(res.data).to.have.property('username');
        expect(res.data.username).to.be.a('string');
      });
  });
});
