# frozen_string_literal: true

RSpec.describe DEQMTestKit::MeasureAvailability do
    let(:suite) { Inferno::Repositories::TestSuites.new.find('deqm_test_suite') }
    let(:group) { suite.groups[2] }
    let(:test_session) { repo_create(:test_session, test_suite_id: 'deqm_test_suite') }
    let(:url) { 'http://example.com/fhir' }
    let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }
  
    def run(runnable, inputs = {})
      test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
      test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
      Inferno::TestRunner.new(test_session: test_session, test_run: test_run).run(runnable, inputs)
      Inferno::Repositories::TestRuns.new.results_for_test_run(test_run.id)
    end
  
    describe 'measure search test' do
      let(:test) { group.tests.first }
      let(:measure_name) { 'EXM130' }
      let(:measure_version) { '7.3.000' }
  
      it 'passes if a Measure was received' do
        resource = FHIR::Bundle.new(total: 1)
        
        stub_request(:get, "#{url}/Measure?name=#{measure_name}&version=#{measure_version}")
          .to_return(status: 200, body: resource.to_json)
  
        # TODO: pass in measure information once it is a measure_availability group input (and in below runs)
        result = run(test, url: url).first
  
        expect(result.result).to eq('pass')
      end
  
      it 'fails if a 200 is not received' do
        resource = FHIR::Bundle.new(total: 1)
        stub_request(:get, "#{url}/Measure?name=#{measure_name}&version=#{measure_version}")
          .to_return(status: 201, body: resource.to_json)
  
        result = run(test, url: url).first
  
        expect(result.result).to eq('fail')
        expect(result.result_message).to match(/200/)
      end
  
      it 'fails if a Measure is not received in the Bundle' do
        resource = FHIR::Bundle.new(total: 0)
        stub_request(:get, "#{url}/Measure?name=#{measure_name}&version=#{measure_version}")
          .to_return(status: 200, body: resource.to_json)
  
        result = run(test, url: url).first
  
        expect(result.result).to eq('fail')
        expect(result.result_message).to match(/measure/)
      end
    end
  end
  