# frozen_string_literal: true
require "json"

# single patient example for Patient/<id>/$everything
$singlePatientFile = File.open('./lib/fixtures/singlePatientBundle.json')
$singlePatientBundle = JSON.parse($singlePatientFile.read).to_json
$singlePatientResponseFile = File.open('./spec/fixtures/singlePatientResponse.json')
$singlePatientResponse = JSON.parse($singlePatientResponseFile.read).to_json

$singlePatientLength = $singlePatientBundle.length()
$singleHeaders = {'Accept'=>'application/fhir+json',
'Accept-Charset'=>'utf-8',
'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
'Content-Length'=> $singlePatientLength.to_s,
'Content-Type'=>'application/fhir+json',
'Host'=>'example.com',
'User-Agent'=>'Ruby FHIR Client'
}

# multiple patient example for Patient/$everything
$multiplePatientFile = File.open('./lib/fixtures/multiplePatientBundle.json')
$multiplePatientBundle = JSON.parse($multiplePatientFile.read).to_json
$multiplePatientResponseFile = File.open('./spec/fixtures/multiplePatientResponse.json')
$multiplePatientResponse = JSON.parse($multiplePatientResponseFile.read).to_json


$multiplePatientLength = $multiplePatientBundle.length()
$multHeaders = {'Accept'=>'application/fhir+json',
'Accept-Charset'=>'utf-8',
'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
'Content-Length'=>$multiplePatientLength.to_s,
'Content-Type'=>'application/fhir+json',
'Host'=>'example.com',
'User-Agent'=>'Ruby FHIR Client'
}

RSpec.describe DEQMTestKit::PatientEverything do
    let(:suite) { Inferno::Repositories::TestSuites.new.find('deqm_test_suite') }
    let(:group) { suite.groups[4] }
    let(:session_data_repo) { Inferno::Repositories::SessionData.new }
    let(:test_session) { repo_create(:test_session, test_suite_id: 'deqm_test_suite') }
    let(:url) { 'http://example.com/fhir' }
    let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }

    def run(runnable, inputs = {})
        test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
        test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
        inputs.each do |name, value|
            session_data_repo.save(test_session_id: test_session.id, name: name, value: value)
        end
        Inferno::TestRunner.new(test_session: test_session, test_run: test_run).run(runnable)
    end

    describe 'Patient/<id>/$everything successful test' do
        let(:test) { group.tests.first }

        it 'passes for valid request to Patient/<id>/$everything' do
            stub_request(:post, "#{url}/").with(body: $singlePatientBundle, headers: $singleHeaders).to_return(status: 200, body: "", headers: {})
            stub_request(:post, "#{url}/Patient/test-patient/$everything").to_return(status: 200, body: $singlePatientResponse, headers: {})
            result = run(test, url: url)
            expect(result.result).to eq('pass')
        end

        it 'fails when server does not return 200' do
            stub_request(:post, "#{url}/").with(body: $singlePatientBundle, headers: $singleHeaders).to_return(status: 200, body: "", headers: {})
            stub_request(:post, "#{url}/Patient/test-patient/$everything").to_return(status: 404, body: error_outcome.to_json)
            result = run(test, url: url)
            expect(result.result).to eq('fail')
            expect(result.result_message).to match(/200/)
        end
    end

    describe 'Patient/$everything successful test' do
        let(:test) { group.tests[1] }

        it 'passes for valid request to Patient/$everything' do
            stub_request(:post, "#{url}/").with(body: $multiplePatientBundle, headers: $multHeaders).to_return(status: 200, body: "", headers: {})
            stub_request(:post, "#{url}/Patient/$everything").to_return(status: 200, body: $multiplePatientResponse, headers: {})
            result = run(test, url: url)
            expect(result.result).to eq('pass')
        end

        it 'fails when server does not return 200' do
            stub_request(:post, "#{url}/").with(body: $multiplePatientBundle, headers: $multHeaders).to_return(status: 200, body: "", headers: {})
            stub_request(:post, "#{url}/Patient/$everything").to_return(status: 404, body: error_outcome.to_json)
            result = run(test, url: url)
            expect(result.result).to eq('fail')
            expect(result.result_message).to match(/200/)
        end
    end

    describe 'Patient/<id>/$everything fails for invalid id' do
        let (:test) { group.tests[2] }

        it 'passes with correct Operation-Outcome returned' do
            stub_request(:post, "#{url}/Patient/INVALID/$everything")
              .to_return(status: 404, body: error_outcome.to_json)
            result = run(test, url: url)
            expect(result.result).to eq('pass')
        end

        it 'fails when server does not return 404' do
            stub_request(
                :post,
                "#{url}/Patient/INVALID/$everything"
            )
                .to_return(status: 200, body: error_outcome.to_json)
            result = run(test, url: url)
            expect(result.result).to eq('fail')
            expect(result.result_message).to match(/404/)
        end
    end
end


