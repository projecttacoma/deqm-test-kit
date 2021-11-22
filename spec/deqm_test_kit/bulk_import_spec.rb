RSpec.describe DEQMTestKit::BulkImport do
    let(:suite) { Inferno::Repositories::TestSuites.new.find('deqm_test_suite') }
    let(:group) { suite.groups[2] }
    let(:session_data_repo) { Inferno::Repositories::SessionData.new }
    let(:test_session) { repo_create(:test_session, test_suite_id: 'deqm_test_suite') }
    url = 'http://example.com/fhir'
    # ensure this url matches url in embedded_client in data_requirements.rb
    let(:embedded_client) do
      'http://cqf_ruler:8080/cqf-ruler-r4/fhir'
    end
    let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }
    let(:test_library_response) { FHIR::Library.new(dataRequirement: [{ type: 'Condition' }]) }
    let(:incorrect_severity) { FHIR::OperationOutcome.new(issue: [{ severity: 'warning' }]) }
    def run(runnable, inputs = {})
      test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
      test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
      inputs.each do |name, value|
        session_data_repo.save(test_session_id: test_session.id, name: name, value: value)
        end
      Inferno::TestRunner.new(test_session: test_session, test_run: test_run).run(runnable)
    end
    describe 'The server is able to perform bulk data tasks' do
      let(:test) { group.tests.first }
      let(:measure_name) { 'EXM130' }
      let(:measure_version) { '7.3.000' }
      let(:measure_id) { 'measure-EXM130-7.3.000' }

      it 'can proceed if a Measure was received' do
        resource = FHIR::Bundle.new(total: 1, entry: [{ resource: { id: 'test_id' } }])
        stub_request(:get, "#{url}/Measure?name=#{measure_name}&version=#{measure_version}")
          .to_return(status: 200, body: resource.to_json)
        result = run(test, url: url)
        expect(result.result).to eq('pass')
     end
    end
end
