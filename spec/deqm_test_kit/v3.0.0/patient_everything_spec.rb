# frozen_string_literal: true

require 'json'

RSpec.describe DEQMTestKit::PatientEverything do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('deqm_v300') }
  let(:group) { suite.groups[9] }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite.id) }
  let(:url) { 'http://example.com/fhir' }
  let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(test_session_id: test_session.id, name:, value:, type: 'text')
    end
    Inferno::TestRunner.new(test_session:, test_run:).run(runnable)
  end

  # Helper method to find the spec file by name
  # `deqm_v300-{patient-everything-id}` <- current naming convention
  def test_by_id(group, patient_everything_id)
    group.tests.find { |t| t.id.end_with?(patient_everything_id) }
  end

  describe 'Patient/<id>/$everything successful test' do
    let(:test) { test_by_id(group, 'patient-everything-single-patient') }

    # single patient example for Patient/<id>/$everything
    single_patient_file = File.open('./lib/fixtures/singlePatientBundle.json')
    single_patient_bundle = JSON.parse(single_patient_file.read).to_json
    single_patient_response_file = File.open('./spec/fixtures/singlePatientResponse.json')
    single_patient_response = JSON.parse(single_patient_response_file.read).to_json

    single_patient_length = single_patient_bundle.length
    single_headers = {
      'Accept' => 'application/fhir+json',
      'Accept-Charset' => 'utf-8',
      'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
      'Content-Length' => single_patient_length.to_s,
      'Content-Type' => 'application/fhir+json',
      'Host' => 'example.com',
      'User-Agent' => 'Ruby FHIR Client'
    }

    it 'passes for valid request to Patient/<id>/$everything' do
      stub_request(:post, "#{url}/").with(body: single_patient_bundle, headers: single_headers).to_return(
        status: 200, body: '', headers: {}
      )
      stub_request(:post, "#{url}/Patient/test-patient/$everything").to_return(
        status: 200, body: single_patient_response, headers: {}
      )
      result = run(test, url:)
      expect(result.result).to eq('pass')
    end

    it 'fails when server does not return 200' do
      stub_request(:post, "#{url}/").with(body: single_patient_bundle, headers: single_headers).to_return(
        status: 200, body: '', headers: {}
      )
      stub_request(:post, "#{url}/Patient/test-patient/$everything").to_return(status: 404,
                                                                               body: error_outcome.to_json)
      result = run(test, url:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/200/)
    end
  end

  describe 'Patient/$everything successful test' do
    let(:test) { test_by_id(group, 'patient-everything-all-patients') }

    # multiple patient example for Patient/$everything
    multiple_patient_file = File.open('./lib/fixtures/multiplePatientBundle.json')
    multiple_patient_bundle = JSON.parse(multiple_patient_file.read).to_json
    multiple_patient_response_file = File.open('./spec/fixtures/multiplePatientResponse.json')
    multiple_patient_response = JSON.parse(multiple_patient_response_file.read).to_json

    multiple_patient_length = multiple_patient_bundle.length
    mult_headers = {
      'Accept' => 'application/fhir+json',
      'Accept-Charset' => 'utf-8',
      'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
      'Content-Length' => multiple_patient_length.to_s,
      'Content-Type' => 'application/fhir+json',
      'Host' => 'example.com',
      'User-Agent' => 'Ruby FHIR Client'
    }

    it 'passes for valid request to Patient/$everything' do
      stub_request(:post, "#{url}/").with(body: multiple_patient_bundle, headers: mult_headers).to_return(
        status: 200, body: '', headers: {}
      )
      stub_request(:post, "#{url}/Patient/$everything").to_return(status: 200, body: multiple_patient_response,
                                                                  headers: {})
      result = run(test, url:)
      expect(result.result).to eq('pass')
    end

    it 'fails when server does not return 200' do
      stub_request(:post, "#{url}/").with(body: multiple_patient_bundle, headers: mult_headers).to_return(
        status: 200, body: '', headers: {}
      )
      stub_request(:post, "#{url}/Patient/$everything").to_return(status: 404, body: error_outcome.to_json)
      result = run(test, url:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/200/)
    end
  end

  describe 'Patient/<id>/$everything fails for invalid id' do
    let(:test) { test_by_id(group, 'patient-everything-invalid-patient-id') }

    it 'passes with correct Operation-Outcome returned' do
      stub_request(:post, "#{url}/Patient/INVALID/$everything")
        .to_return(status: 404, body: error_outcome.to_json)
      result = run(test, url:)
      expect(result.result).to eq('pass')
    end

    it 'fails when server does not return 404' do
      stub_request(
        :post,
        "#{url}/Patient/INVALID/$everything"
      )
        .to_return(status: 200, body: error_outcome.to_json)
      result = run(test, url:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/404/)
    end
  end
end
