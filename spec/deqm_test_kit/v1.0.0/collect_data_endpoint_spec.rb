# frozen_string_literal: true

require_relative '../../utils/collect_data_spec_utils'

RSpec.describe DEQMTestKit::CollectDataEndpointV1 do
  include DEQMTestKit::CollectDataSpecUtils

  let(:suite) { Inferno::Repositories::TestSuites.new.find('deqm_v100') }
  let(:group) { suite.groups[3] }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite.id) }
  let(:url) { 'http://example.com/fhir' }
  let(:data_endpoint) do
    {
      resourceType: 'Endpoint',
      status: 'active',
      connectionType: { system: 'http://terminology.hl7.org/CodeSystem/endpoint-connection-type',
                        code: 'hl7-fhir-rest' },
      address: 'https://r4.smarthealthit.org'
    }.to_json
  end

  describe 'POST Measure/$collect-data with one measureUrl, subject, and dataEndpoint' do
    let(:test) { test_by_id(group, 'collect-data-one-measure-data-endpoint-subject-patient') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:patient_id) { 'numer-EXM130' }

    it 'passes with correct FHIR Parameters resource returned' do
      parameters_request = create_parameters_request(
        measure_urls: [measure_url], period_start:, period_end:, patient_id:, data_endpoint:
      )
      parameters_response = create_parameters_response(measure_urls: [measure_url])

      stub_request(
        :post,
        "#{url}/Measure/$collect-data"
      ).with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => url,
          'Referrer' => url
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_url:, period_start:, period_end:, patient_id:, data_endpoint:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$collect-data with two measureUrls, subject, and dataEndpoint' do
    let(:test) { test_by_id(group, 'collect-data-two-measure-data-endpoint-subject-patient') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:additional_measure_url) { 'http://example.com/Measure/measure-EXM124' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:patient_id) { 'numer-EXM130' }

    it 'passes with correct FHIR Parameters resource returned' do
      measure_urls = [measure_url, additional_measure_url]
      parameters_request = create_parameters_request(
        measure_urls:, period_start:, period_end:, patient_id:, data_endpoint:
      )
      parameters_response = create_parameters_response(measure_urls:)

      stub_request(
        :post, "#{url}/Measure/$collect-data"
      ).with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => url,
          'Referrer' => url
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(
        test, url:, measure_url:, additional_measure_url:, period_start:, period_end:, patient_id:, data_endpoint:
      )
      expect(result.result).to eq('pass')
    end
  end
end
