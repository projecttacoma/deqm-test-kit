# frozen_string_literal: true

RSpec.describe DEQMTestKit::MeasureAvailability do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('deqm_test_suite') }
  let(:group) { suite.groups[1] }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite.id) }
  let(:url) { 'http://example.com/fhir' }
  let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(test_session_id: test_session.id, name: name, value: value, type: 'text')
    end
    Inferno::TestRunner.new(test_session: test_session, test_run: test_run).run(runnable)
  end

  describe 'measure search test' do
    let(:test) { group.tests.first }
    let(:measure_name) { 'EXM130' }
    let(:measure_version) { '7.3.000' }
    let(:selected_measure_id) { 'EXM130|7.3.000' }

    it 'passes if a Measure was received' do
      resource = FHIR::Bundle.new(total: 1, entry: [{ resource: { id: 'test_id' } }])

      stub_request(:get, "#{url}/Measure?name=#{measure_name}&version=#{measure_version}")
        .to_return(status: 200, body: resource.to_json)

      # TODO: pass in measure information once it is a measure_availability group input (and in below runs)
      result = run(test, selected_measure_id: selected_measure_id, url: url)

      expect(result.result).to eq('pass')
    end

    it 'fails if a 200 is not received' do
      resource = FHIR::Bundle.new(total: 1)
      stub_request(:get, "#{url}/Measure?name=#{measure_name}&version=#{measure_version}")
        .to_return(status: 201, body: resource.to_json)

      result = run(test, selected_measure_id: selected_measure_id, url: url)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/200/)
    end

    it 'fails if a Measure is not received in the Bundle' do
      resource = FHIR::Bundle.new(total: 0)
      stub_request(:get, "#{url}/Measure?name=#{measure_name}&version=#{measure_version}")
        .to_return(status: 200, body: resource.to_json)

      result = run(test, selected_measure_id: selected_measure_id, url: url)

      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/measure/)
    end
  end
end
