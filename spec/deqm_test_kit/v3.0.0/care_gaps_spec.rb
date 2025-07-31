# frozen_string_literal: true

RSpec.describe DEQMTestKit::CareGaps do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('deqm_v300') }
  let(:group) { suite.groups[6] }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite.id) }
  let(:url) { 'http://example.com/fhir' }
  let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }
  let(:test_parameters) { FHIR::Parameters.new(total: 1) }

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(test_session_id: test_session.id, name:, value:, type: 'text')
    end
    Inferno::TestRunner.new(test_session:, test_run:).run(runnable)
  end

  describe '$care-gaps successful test with required query parameters (Patient)' do
    let(:test) { test_by_id(group, 'care-gaps-patient-subject-with-required-params') }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    let(:params) do
      "measureId=#{measure_id}&periodStart=#{period_start}&periodEnd=#{period_end}" \
        "&subject=Patient/#{patient_id}&status=open-gap"
    end

    it 'passes if request has valid parameters, patient id, and measure id' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 200, body: test_parameters.to_json)
      result = run(test, url:, measure_id:, patient_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('pass')
    end
    it 'fails if $care-gaps does not return 200' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 400, body: test_parameters.to_json)
      result = run(test, url:, measure_id:, patient_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('fail')
    end
    it 'fails if $care-gaps does not return a Parameters object' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 200, body: error_outcome.to_json)
      result = run(test, url:, measure_id:, patient_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('fail')
    end
  end

  describe '$care-gaps successful test with Group subject' do
    let(:test) { test_by_id(group, 'care-gaps-group-subject-with-required-params') }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:group_id) { 'EXM130-patients' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    let(:params) do
      "measureId=#{measure_id}&periodStart=#{period_start}&periodEnd=#{period_end}" \
        "&subject=Group/#{group_id}&status=open-gap"
    end

    it 'passes if request has valid parameters' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 200, body: test_parameters.to_json)
      result = run(test, url:, measure_id:, group_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('pass')
    end
    it 'fails if $care-gaps does not return 200' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 400, body: test_parameters.to_json)
      result = run(test, url:, measure_id:, group_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('fail')
    end
    it 'fails if $care-gaps does not return Parameters object' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 200, body: error_outcome.to_json)
      result = run(test, url:, measure_id:, group_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('fail')
    end
  end

  describe '$care-gaps missing required parameter test' do
    let(:test) { test_by_id(group, 'care-gaps-missing-required-parameter') }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_end) { '2019-12-31' }
    let(:params) do
      "measureId=#{measure_id}&periodEnd=#{period_end}&subject=Patient/#{patient_id}&status=open-gap"
    end
    it 'passes if request returns 400 with OperationOutcome' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 400, body: error_outcome.to_json)
      result = run(test, url:, measure_id:, patient_id:,
                         period_end:)
      expect(result.result).to eq('pass')
    end
    it 'fails if request returns 200' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 200, body: error_outcome.to_json)
      result = run(test, url:, measure_id:, patient_id:,
                         period_end:)
      expect(result.result).to eq('fail')
    end
    it 'fails if request returns a Parameters object' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 400, body: test_parameters.to_json)
      result = run(test, url:, measure_id:, patient_id:,
                         period_end:)
      expect(result.result).to eq('fail')
    end
  end

  describe '$care-gaps has subject and organization test' do
    let(:test) { test_by_id(group, 'care-gaps-subject-and-organization-conflict') }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:params) do
      "measureId=#{measure_id}&periodStart=#{period_start}&periodEnd=#{period_end}" \
        "&status=open-gap&organization=Organization/testOrganization&subject=Patient/#{patient_id}"
    end
    it 'passes if request returns 400 with OperationOutcome' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 400, body: error_outcome.to_json)
      result = run(test, url:, measure_id:, patient_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('pass')
    end
    it 'fails if request returns 200' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 200, body: error_outcome.to_json)
      result = run(test, url:, measure_id:, patient_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('fail')
    end
    it 'fails if request returns a Parameters object' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 404, body: test_parameters.to_json)
      result = run(test, url:, measure_id:, patient_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('fail')
    end
  end

  describe '$care-gaps has invalid subject format test' do
    let(:test) { test_by_id(group, 'care-gaps-invalid-subject-format') }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) { 'INVALID_SUBJECT_ID' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:params) do
      "measureId=#{measure_id}&periodStart=#{period_start}&periodEnd=#{period_end}" \
        "&status=open-gap&subject=#{patient_id}"
    end
    it 'passes if request returns 400 with OperationOutcome' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 400, body: error_outcome.to_json)
      result = run(test, url:, measure_id:, patient_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('pass')
    end
    it 'fails if request returns 200' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 200, body: error_outcome.to_json)
      result = run(test, url:, measure_id:, patient_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('fail')
    end
    it 'fails if request returns a parameters object' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 404, body: test_parameters.to_json)
      result = run(test, url:, measure_id:, patient_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('fail')
    end
  end

  describe '$care-gaps successful test with no measure identifier' do
    let(:test) { test_by_id(group, 'care-gaps-no-measure-identifier-provided') }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:params) do
      "periodStart=#{period_start}&periodEnd=#{period_end}" \
        "&subject=Patient/#{patient_id}&status=open-gap"
    end
    it 'passes if request has valid parameters and patient id without measure id' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 200, body: test_parameters.to_json)
      result = run(test, url:, patient_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe '$care-gaps has invalid measure id test' do
    let(:test) { test_by_id(group, 'care-gaps-invalid-measure-identifier') }
    let(:measure_id) { 'INVALID_MEASURE_ID' }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:test_parameters) { FHIR::Parameters.new(total: 1) }
    let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }
    let(:params) do
      "measureId=#{measure_id}&periodStart=#{period_start}&periodEnd=#{period_end}" \
        "&subject=Patient/#{patient_id}&status=open-gap"
    end
    it 'passes if request returns 404 with OperationOutcome' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 404, body: error_outcome.to_json)
      result = run(test, url:, measure_id:, patient_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('pass')
    end
    it 'fails if request returns 200' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 200, body: error_outcome.to_json)
      result = run(test, url:, measure_id:, patient_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('fail')
    end
    it 'fails if request returns a parameters object' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 404, body: test_parameters.to_json)
      result = run(test, url:, measure_id:, patient_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('fail')
    end
  end

  describe '$care-gaps successful test with practitioner and organization' do
    let(:test) { test_by_id(group, 'care-gaps-practitioner-and-organization-params') }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:practitioner_id) { '1' }
    let(:org_id) { '1' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:params) do
      "measureId=#{measure_id}&periodStart=#{period_start}&periodEnd=#{period_end}" \
        "&practitioner=Practitioner/#{practitioner_id}&organization=Organization/#{org_id}&status=open-gap"
    end

    it 'passes if request has valid parameters' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 200, body: test_parameters.to_json)
      result = run(test, url:, measure_id:, practitioner_id:, org_id:,
                         period_start:, period_end:)
      expect(result.result).to eq('pass')
    end
    it 'fails if $care-gaps does not return 200' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 400, body: test_parameters.to_json)
      result = run(test, url:, measure_id:, practitioner_id:, org_id:,
                         period_start:, period_end:)
      expect(result.result).to eq('fail')
    end
    it 'fails if $care-gaps does not return Parameters object' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 200, body: error_outcome.to_json)
      result = run(test, url:, measure_id:, practitioner_id:, org_id:,
                         period_start:, period_end:)
      expect(result.result).to eq('fail')
    end
  end

  describe '$care-gaps successful test with program' do
    let(:test) { test_by_id(group, 'care-gaps-with-program-parameter') }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    let(:params) do
      "program=eligible-provider&periodStart=#{period_start}&periodEnd=#{period_end}" \
        "&subject=Patient/#{patient_id}&status=open-gap"
    end
    it 'passes if request has valid parameters' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 200, body: test_parameters.to_json)
      result = run(test, url:, program: 'eligible-provider', patient_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('pass')
    end
    it 'fails if $care-gaps does not return 200' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 400, body: test_parameters.to_json)
      result = run(test, url:, program: 'eligible-provider', patient_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('fail')
    end
    it 'fails if $care-gaps does not return Parameters object' do
      stub_request(
        :post,
        "#{url}/Measure/$care-gaps?#{params}"
      ).to_return(status: 200, body: error_outcome.to_json)
      result = run(test, url:, program: 'eligible-provider', patient_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('fail')
    end
  end
end
