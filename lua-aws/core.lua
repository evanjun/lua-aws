local class = require('lua-aws.class')
local Credentials = require('lua-aws.credentials')
local util = require('lua-aws.util')
local available_engines = require 'lua-aws.engines.available'
assert(available_engines)

local AWS = class.AWS {
	VERSION = 'v0.1.0',
	initialize = function (self, config, http_engine)
		assert(config)
		if http_engine then -- backward conpatibility
			if not config.preferred_engines then
				config.preferred_engines = {}
			end
			config.preferred_engines.http = http_engine
		end
		local engines = self:init_engines(config.preferred_engines or {})
		self._http_engine = engines.http
		self._json_engine = engines.json
		self._fs_engine = engines.fs
		-- check or retrieve credentials / force enable SSL for default
		self._config = self:verify_and_fill_config(config)
		--self._http_engine = http_engine or self:get_http_engine()
		--> define service
		if not self._config.lazyInitialization then
			self:init_services()
		end
  	
		--[[
		require('./services/autoscaling')
		require('./services/cloudformation')
		require('./services/cloudfront')
		require('./services/cloudsearch')
		require('./services/cloudwatch')
		require('./services/datapipeline')
		require('./services/directconnect')
		require('./services/elasticache')
		require('./services/elasticbeanstalk')
		require('./services/elastictranscoder')
		require('./services/elb')
		require('./services/emr')
		require('./services/glacier')
		require('./services/iam')
		require('./services/importexport')
		require('./services/opsworks')
		require('./services/rds')
		require('./services/redshift')
		require('./services/route53')
		require('./services/s3')
		require('./services/ses')
		require('./services/simpledb')
		require('./services/simpleworkflow')
		require('./services/sns')
		require('./services/sqs')
		require('./services/storagegateway')
		require('./services/sts')
		require('./services/support')
		]]--	
	end,
	-- call proper place if you set lazyInitialization to your config
	-- TODO: more lazy. (per service, when accessed)
	init_services = function (self, config)
		self.DynamoDB = require('lua-aws.services.dynamodb').new(self)
		self.EC2 = require('lua-aws.services.ec2').new(self)
		self.Kinesis = require('lua-aws.services.kinesis').new(self)
		self.SNS = require('lua-aws.services.sns').new(self)
		self.SQS = require('lua-aws.services.sqs').new(self)
		self.SWF = require('lua-aws.services.swf').new(self)
		self.CloudWatch = require('lua-aws.services.cloudwatch').new(self, "monitoring")
		self.CloudWatchLog = require('lua-aws.services.cloudwatchlog').new(self, "logs")
		self.S3 = require('lua-aws.services.s3').new(self)
		self.ECS = require('lua-aws.services.ecs').new(self)
		self.Athena = require('lua-aws.services.athena').new(self)
		self.Firehose = require('lua-aws.services.firehose').new(self)
		self.Lambda = require('lua-aws.services.lambda').new(self)
		self.IAM = require('lua-aws.services.iam').new(self)
		self.STS = require('lua-aws.services.sts').new(self)
	end,
	verify_and_fill_config = function (self, config)
		if config.sslEnabled == nil then
			config.sslEnabled = true
		elseif not config.sslEnabled then
			print('https disabled: its strongly recommended to use https instead of non-secure version')
		end
		if config.role then
			-- get credential from role
			assert(self._http_engine and self._json_engine) -- http/json should be already initialized
			local resp = self:http_request({
				path = ('/latest/meta-data/iam/security-credentials/' .. config.role),
				headers = {},
				host = '169.254.169.254',
				port = 80,
				protocol = 'http',
				method = 'GET'
			})
			local obj = self._json_engine.decode(resp.body)
			config.credentials = Credentials.new({
				accessKeyId = obj.AccessKeyId,
				secretAccessKey = obj.SecretAccessKey,
				sessionToken = obj.Token,
			})
		elseif config.accessKeyId and config.secretAccessKey then
			config.credentials = Credentials.new(config)
		end
		assert(config.credentials)
		return config
	end,
	init_engines = function (self, preferred)
		local ok, r 
		local selected_engines = {}
		for k,v in pairs(available_engines) do
			if preferred[k] then
				local t = type(preferred[k])
				if t == 'string' then
					selected_engines[k] = self:try_load_engines(k, preferred[k])
					if preferred.strict then
						assert(selected_engines[k], "application require "..preferred[k].." for "..k.." strictly but cannot")
					end
				else
					selected_engines[k] = preferred[k]
				end
			end
			if not selected_engines[k] then
				for i=1,#v do
					if (not preferred[k]) or (v[i] ~= preferred[k]) then
						selected_engines[k] = self:try_load_engines(k, v[i])
						if selected_engines[k] then
							break
						end	
					end
				end
			end
			assert(selected_engines[k], "no engine for "..k.." available")
		end
		return selected_engines
	end,
	try_load_engines = function (self, engine_type, engine_name)
		local ok, r = pcall(require, 'lua-aws.engines.'..engine_type..'.'..engine_name)
		if not ok then
			if not r:match('module.+not found') then
				print('try_load_engines error:', r)
			end
		end
		return ok and r
	end,
	fs = function (self)
		return self._fs_engine
	end,
	json = function (self)
		return self._json_engine
	end,
	config = function (self)
		return self._config
	end,
	service_definition_version = function (self)
		return self._config.service_definition_version or 1
	end,
	api_log = function (self, api, ...)
		print(api:endpoint_prefix() .. ':v[' .. api:version() .. ']:', ...)
	end,
	http_request = function (self, req, resp)
		return self._http_engine(req, resp)
	end,
}
--[[
require('./sequential_executor');
require('./event_listeners');
require('./signers/request_signer');
require('./param_validator');
require('./metadata_service');
]]--
return AWS
