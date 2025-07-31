# frozen_string_literal: true

RSpec.describe DEQMTestKit::BulkImport do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('deqm_v300') }
  let(:group) { suite.groups[8] }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite.id) }
  let(:url) { 'http://example.com/fhir' }

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(test_session_id: test_session.id, name:, value:, type: 'text')
    end
    Inferno::TestRunner.new(test_session:, test_run:).run(runnable)
  end

  # Helper method to find the spec file by name
  # `deqm_v300-{bulk-import-id}` <- current naming convention
  def test_by_id(group, bulk_import_id)
    group.tests.find { |t| t.id.end_with?(bulk_import_id) }
  end

  describe 'The server is able to accept bulk data import requests' do
    let(:test) { test_by_id(group, 'bulk-import-accepts-import-requests') }

    it 'passes on successful $import' do
      resource = FHIR::Bundle.new(total: 1, entry: [{ resource: { id: 'test_id' } }])
      polling_url = "#{url}/location"
      export_url = 'http://example-export-url.com/$export'

      stub_request(:post, "#{url}/$import")
        .to_return(status: 200, body: resource.to_json, headers: { 'content-location': polling_url })
      stub_request(:get, polling_url)
        .to_return(status: 202, body: resource.to_json).times(3)

      stub_request(:get, polling_url)
        .to_return(status: 200, body: resource.to_json)
      result = run(test, url:, types: 'Patient', exportUrl: export_url)
      # check that we get a 202 off a bulk data request
      expect(result.result).to eq('pass')
    end
  end
end
