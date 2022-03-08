# frozen_string_literal: true

RSpec.describe DEQMTestKit::CareGaps do
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
      session_data_repo.save(test_session_id: test_session.id, name: name, value: value, type: 'text')
    end
    Inferno::TestRunner.new(test_session: test_session, test_run: test_run).run(runnable)
  end

  describe '$care-gaps successful test' do
    let(:test) { group.tests.first }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) { 'Patient/numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:test_parameters) { FHIR::Parameters.new(total: 1) }
    let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }

    let(:params) do
      "measureId=#{measure_id}&periodStart=#{period_start}&periodEnd=#{period_end}"\
        "&subject=#{patient_id}&status=open-gap"
    end
    test_parameters = FHIR::Parameters.new(total: 1)
    it 'passes if request has valid parameters, patient id, and measure id' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 200, body: test_parameters.to_json)
      result = run(test, url: url, measure_id: measure_id, patient_id: patient_id, period_start: period_start,
                         period_end: period_end)
      expect(result.result).to eq('pass')
    end
    it 'passes if request has valid parameters, patient id, and measure id' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 400, body: test_parameters.to_json)
      result = run(test, url: url, measure_id: measure_id, patient_id: patient_id, period_start: period_start,
                         period_end: period_end)
      expect(result.result).to eq('fail')
    end
    it 'passes if request has valid parameters, patient id, and measure id' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 400, body: error_outcome.to_json)
      result = run(test, url: url, measure_id: measure_id, patient_id: patient_id, period_start: period_start,
                         period_end: period_end)
      expect(result.result).to eq('fail')
    end
  end
  describe '$care-gaps missing required parameter test' do
    let(:test) { group.tests[1] }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:test_parameters) { FHIR::Parameters.new(total: 1) }
    let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }
    let(:params) do
      "measureId=#{measure_id}&periodEnd=#{period_end}&subject=#{patient_id}&status=open-gap"
    end
    it 'passes if request returns 400 with OperationOutcome' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 400, body: error_outcome.to_json)
      result = run(test, url: url, measure_id: measure_id, patient_id: patient_id, period_start: period_start,
                         period_end: period_end)
      expect(result.result).to eq('pass')
    end
    it 'fails if request returns 200' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 200, body: error_outcome.to_json)
      result = run(test, url: url, measure_id: measure_id, patient_id: patient_id, period_start: period_start,
                         period_end: period_end)
      expect(result.result).to eq('fail')
    end
    it 'fails if request returns a parameters object' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 400, body: test_parameters.to_json)
      result = run(test, url: url, measure_id: measure_id, patient_id: patient_id, period_start: period_start,
                         period_end: period_end)
      expect(result.result).to eq('fail')
    end
  end
  describe '$care-gaps has invalid optional parameters test' do
    let(:test) { group.tests[2] }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:test_parameters) { FHIR::Parameters.new(total: 1) }
    let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }
    let(:params) do
      "measureId=#{measure_id}&periodStart=#{period_start}&periodEnd=#{period_end}"\
        "&status=open-gap&practitioner=INVALID&organization=INVALID&subject=#{patient_id}"
    end
    it 'passes if request returns 501 with OperationOutcome' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 501, body: error_outcome.to_json)
      result = run(test, url: url, measure_id: measure_id, patient_id: patient_id, period_start: period_start,
                         period_end: period_end)
      expect(result.result).to eq('pass')
    end
    it 'fails if request returns 200' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 200, body: error_outcome.to_json)
      result = run(test, url: url, measure_id: measure_id, patient_id: patient_id, period_start: period_start,
                         period_end: period_end)
      expect(result.result).to eq('fail')
    end
    it 'fails if request returns a bundle' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 404, body: test_parameters.to_json)
      result = run(test, url: url, measure_id: measure_id, patient_id: patient_id, period_start: period_start,
                         period_end: period_end)
      expect(result.result).to eq('fail')
    end
  end
  describe '$care-gaps has invalid subject test' do
    let(:test) { group.tests[3] }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:test_parameters) { FHIR::Parameters.new(total: 1) }
    let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }
    let(:params) do
      "measureId=#{measure_id}&periodStart=#{period_start}&periodEnd=#{period_end}&status=open-gap&subject=INVALID"
    end
    it 'passes if request returns 400 with OperationOutcome' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 400, body: error_outcome.to_json)
      result = run(test, url: url, measure_id: measure_id, patient_id: patient_id, period_start: period_start,
                         period_end: period_end)
      expect(result.result).to eq('pass')
    end
    it 'fails if request returns 200' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 200, body: error_outcome.to_json)
      result = run(test, url: url, measure_id: measure_id, patient_id: patient_id, period_start: period_start,
                         period_end: period_end)
      expect(result.result).to eq('fail')
    end
    it 'fails if request returns a parameters object' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 404, body: test_parameters.to_json)
      result = run(test, url: url, measure_id: measure_id, patient_id: patient_id, period_start: period_start,
                         period_end: period_end)
      expect(result.result).to eq('fail')
    end
  end
  describe '$care-gaps successful test with no measure identifier' do
    let(:test) { group.tests[4] }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) { 'Patient/numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:test_parameters) { FHIR::Parameters.new(total: 1) }
    let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }
    let(:params) do
      "periodStart=#{period_start}&periodEnd=#{period_end}"\
        "&subject=#{patient_id}&status=open-gap"
    end
    it 'passes if request has valid parameters and patient id without measure id' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 200, body: test_parameters.to_json)
      result = run(test, url: url, measure_id: measure_id, patient_id: patient_id, period_start: period_start,
                         period_end: period_end)
      expect(result.result).to eq('pass')
    end
  end
  describe '$care-gaps has invalid measure id test' do
    let(:test) { group.tests[5] }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:test_parameters) { FHIR::Parameters.new(total: 1) }
    let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }
    let(:params) do
      "measureId=INVALID_MEASURE&periodStart=#{period_start}&periodEnd=#{period_end}"\
        "&subject=#{patient_id}&status=open-gap"
    end
    it 'passes if request returns 400 with OperationOutcome' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 404, body: error_outcome.to_json)
      result = run(test, url: url, measure_id: measure_id, patient_id: patient_id, period_start: period_start,
                         period_end: period_end)
      expect(result.result).to eq('pass')
    end
    it 'fails if request returns 200' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 200, body: error_outcome.to_json)
      result = run(test, url: url, measure_id: measure_id, patient_id: patient_id, period_start: period_start,
                         period_end: period_end)
      expect(result.result).to eq('fail')
    end
    it 'fails if request returns a parameters object' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 404, body: test_parameters.to_json)
      result = run(test, url: url, measure_id: measure_id, patient_id: patient_id, period_start: period_start,
                         period_end: period_end)
      expect(result.result).to eq('fail')
    end
  end
end
