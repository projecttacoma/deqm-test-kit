# frozen_string_literal: true

RSpec.describe DEQMTestKit::EvaluateMeasure do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('deqm_test_suite') }
  let(:group) { suite.groups[5] }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: 'deqm_test_suite') }
  url = 'http://example.com/fhir'
  let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(test_session_id: test_session.id, name: name, value: value)
    end
    Inferno::TestRunner.new(test_session: test_session, test_run: test_run).run(runnable)
  end

  describe '$evaluate-measure successful test' do
    let(:test) { groups.test.first }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) {'numer-EXM130'}
    let(:period_start) {'2019-01-01'}
    let(:period_end) {'2019-12-31'}

    params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=#{patient_id}"

    it 'passes if request has valid parameters, patient id, and measure id' do
      params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=#{patient_id}"
      test_measure_report = FHIR::MeasureReport.new(entry: [{ resource: {resourceType: MeasureReport, measure: measure_id}}])
      stub_request(:post, "#{url}/Measure/#{measure_id}/$evaluate-measure?#{params}")
        .to_return(status: 200, body: test_measure_report.to_json)
    end

    it 'fails if $evaluate-measure does not return 200'
      stub_request(:post, "#{url}/Measure/#{measure_id}/$evaluate-measure?#{params}").to_return(status: 404, body: error_outcome.to_json)
      params = "periodStart=#{period_start}&periodEnd=#{period_end}&subject=#{patient_id}"  
      result = run(test, url: url, measure_id: measure_id)
        expect(result.result).to eq('fail')
        expect(result.result_message).to match(/200/)
  end
end
