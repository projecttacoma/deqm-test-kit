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
    let(:test) { group.tests.first }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:params) { "periodStart=#{period_start}&periodEnd=#{period_end}&subject=#{patient_id}" }

    it 'passes if request has valid parameters, patient id, and measure id' do
      test_measure_report = FHIR::MeasureReport.new(entry: [{ resource: {resourceType: 'MeasureReport', measure: measure_id}}])
      stub_request(:post, "#{url}/Measure/#{measure_id}/$evaluate-measure?#{params}")
        .to_return(status: 200, body: test_measure_report.to_json)
    end

    it 'fails if $evaluate-measure does not return 200' do
      stub_request(:post, "#{url}/Measure/#{measure_id}/$evaluate-measure?#{params}").to_return(status: 404, body: error_outcome.to_json) 
      result = run(test, url: url, measure_id: measure_id, patient_id: patient_id, period_start: period_start, period_end: period_end)
         expect(result.result).to eq('fail')
         expect(result.result_message).to match(/200/)
    end
  end

  describe '$evaluate-measure fails for invalid measure id' do
    let(:test) { group.tests[1] }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:params) { "periodStart=#{period_start}&periodEnd=#{period_end}&subject=#{patient_id}" }

    INVALID_MEASURE_ID = 'INVALID_MEASURE_ID'

    it 'passes with correct Operation-Outcome returned' do
      stub_request(:post, "#{url}/Measure/#{INVALID_MEASURE_ID}/$evaluate-measure?#{params}")
        .to_return(status: 404, body: error_outcome.to_json)
      result = run(test, url: url, patient_id: patient_id, period_start: period_start, period_end: period_end)
      expect(result.result).to eq('pass')
    end

    it 'fails if server does not return 404 for invalid measure id' do
      stub_request(:post, "#{url}/Measure/#{INVALID_MEASURE_ID}/$evaluate-measure?#{params}").to_return(status: 200, body: error_outcome.to_json) 
      result = run(test, url: url, patient_id: patient_id, period_start: period_start, period_end: period_end)
         expect(result.result).to eq('fail')
         expect(result.result_message).to match(/404/)
    end
  end

  describe '$evaluate-measure fails for invalid patient id' do
    let(:test) { group.tests[2] }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:params) { "periodStart=#{period_start}&periodEnd=#{period_end}&subject=#{INVALID_PATIENT_ID}" }

    INVALID_PATIENT_ID = 'INVALID_PATIENT_ID'

    it 'passes with correct Operation-Outcome returned' do
      stub_request(:post, "#{url}/Measure/#{measure_id}/$evaluate-measure?#{params}")
        .to_return(status: 404, body: error_outcome.to_json)
      result = run(test, url: url, measure_id: measure_id, period_start: period_start, period_end: period_end)
      expect(result.result).to eq('pass')
    end

    it 'fails if server does not return 404 for invalid patient id' do
      stub_request(:post, "#{url}/Measure/#{measure_id}/$evaluate-measure?#{params}").to_return(status: 200, body: error_outcome.to_json) 
      result = run(test, url: url, measure_id: measure_id, period_start: period_start, period_end: period_end)
         expect(result.result).to eq('fail')
         expect(result.result_message).to match(/404/)
    end
  end

  describe '$evaluate-measure fails for missing required params' do
    let(:test) { group.tests[3] }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_end) { '2019-12-31' }
    let(:params) { "periodEnd=#{period_end}&subject=#{patient_id}" }

    it 'passes with correct Operation-Outcome returned' do
      stub_request(:post, "#{url}/Measure/#{measure_id}/$evaluate-measure?#{params}")
        .to_return(status: 400, body: error_outcome.to_json)
      result = run(test, url: url, measure_id: measure_id, patient_id: patient_id, period_end: period_end)
      expect(result.result).to eq('pass')
    end

    it 'fails if server does not return 400 for missing param' do
      stub_request(:post, "#{url}/Measure/#{measure_id}/$evaluate-measure?#{params}").to_return(status: 200, body: error_outcome.to_json) 
      result = run(test, url: url, measure_id: measure_id, patient_id: patient_id, period_end: period_end)
         expect(result.result).to eq('fail')
         expect(result.result_message).to match(/400/)
    end
  end

  describe '$evaluate-measure fails for missing subject param for individual report type' do
    let(:test) { group.tests[4] }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:params) { "periodStart=#{period_start}&periodEnd=#{period_end}" }

    it 'passes with correct Operation-Outcome returned' do
      stub_request(:post, "#{url}/Measure/#{measure_id}/$evaluate-measure?#{params}")
        .to_return(status: 400, body: error_outcome.to_json)
      result = run(test, url: url, measure_id: measure_id, period_start: period_start, period_end: period_end)
      expect(result.result).to eq('pass')
    end

    it 'fails if server does not return 400 for missing subject param' do
      stub_request(:post, "#{url}/Measure/#{measure_id}/$evaluate-measure?#{params}").to_return(status: 200, body: error_outcome.to_json) 
      result = run(test, url: url, measure_id: measure_id, period_start: period_start, period_end: period_end)
         expect(result.result).to eq('fail')
         expect(result.result_message).to match(/400/)
    end
  end

  describe '$evaluate-measure fails for unsupported subject-list support type' do
    let(:test) { group.tests[5] }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:params) { "periodStart=#{period_start}&periodEnd=#{period_end}&subject=#{patient_id}&reportType=subject-list" }

    it 'passes with correct Operation-Outcome returned' do
      stub_request(:post, "#{url}/Measure/#{measure_id}/$evaluate-measure?#{params}")
        .to_return(status: 501, body: error_outcome.to_json)
      result = run(test, url: url, measure_id: measure_id, patient_id: patient_id, period_start: period_start, period_end: period_end)
      expect(result.result).to eq('pass')
    end

    it 'fails if server does not return 501 for unsupported subject-list' do
      stub_request(:post, "#{url}/Measure/#{measure_id}/$evaluate-measure?#{params}").to_return(status: 200, body: error_outcome.to_json) 
      result = run(test, url: url, measure_id: measure_id, patient_id: patient_id, period_start: period_start, period_end: period_end)
         expect(result.result).to eq('fail')
         expect(result.result_message).to match(/501/)
    end
  end

  describe '$evaluate-measure fails for unsupported param included' do
    let(:test) { group.tests[6] }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:params) { "periodStart=#{period_start}&periodEnd=#{period_end}&subject=#{patient_id}&lastReceivedOn=2019-12-31" }

    it 'passes with correct Operation-Outcome returned' do
      stub_request(:post, "#{url}/Measure/#{measure_id}/$evaluate-measure?#{params}")
        .to_return(status: 400, body: error_outcome.to_json)
      result = run(test, url: url, measure_id: measure_id, patient_id: patient_id, period_start: period_start, period_end: period_end)
      expect(result.result).to eq('pass')
    end

    it 'fails if server does not return 400 for unsupported param' do
      stub_request(:post, "#{url}/Measure/#{measure_id}/$evaluate-measure?#{params}").to_return(status: 200, body: error_outcome.to_json) 
      result = run(test, url: url, measure_id: measure_id, patient_id: patient_id, period_start: period_start, period_end: period_end)
         expect(result.result).to eq('fail')
         expect(result.result_message).to match(/400/)
    end
  end

  describe '$evaluate-measure fails for invalid reportType' do
    let(:test) { group.tests[7] }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:params) { "periodStart=#{period_start}&periodEnd=#{period_end}&subject=#{patient_id}&reportType=INVALID" }

    it 'passes with correct Operation-Outcome returned' do
      stub_request(:post, "#{url}/Measure/#{measure_id}/$evaluate-measure?#{params}")
        .to_return(status: 400, body: error_outcome.to_json)
      result = run(test, url: url, measure_id: measure_id, patient_id: patient_id, period_start: period_start, period_end: period_end)
      expect(result.result).to eq('pass')
    end

    it 'fails if server does not return 400 for invalid reportType' do
      stub_request(:post, "#{url}/Measure/#{measure_id}/$evaluate-measure?#{params}").to_return(status: 200, body: error_outcome.to_json) 
      result = run(test, url: url, measure_id: measure_id, patient_id: patient_id, period_start: period_start, period_end: period_end)
         expect(result.result).to eq('fail')
         expect(result.result_message).to match(/400/)
    end
  end
end
