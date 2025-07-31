# frozen_string_literal: true

INVALID_MEASURE_ID = 'INVALID_MEASURE_ID'
INVALID_PATIENT_ID = 'INVALID_PATIENT_ID'
INVALID_REPORT_TYPE = 'INVALID_REPORT_TYPE'
INVALID_START_DATE = 'INVALID_START_DATE'

RSpec.describe DEQMTestKit::Evaluate do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('deqm_v500') }
  let(:group) { suite.groups[4] }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite.id) }
  let(:url) { 'http://example.com/fhir' }
  let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }

  # Helper method to create a valid Parameters response
  def create_parameters_response(measure_report_type)
    measure_report = FHIR::MeasureReport.new(
      status: 'complete', type: measure_report_type,
      measure: 'measure-EXM130-7.3.000',
      period: { start: '2019-01-01', end: '2019-12-31' }
    )
    bundle = FHIR::Bundle.new(type: 'collection', entry: [{ resource: measure_report }])
    FHIR::Parameters.new(parameter: [{ resource: bundle }])
  end

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(test_session_id: test_session.id, name:, value:, type: 'text')
    end
    Inferno::TestRunner.new(test_session:, test_run:).run(runnable)
  end

  describe 'Measure/[id]/$evaluate with reportType=population' do
    let(:test) { test_by_id(group, 'evaluate-measureid-query-default-reporttype') }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with correct parameter resource returned' do
      parameters_response = create_parameters_response('individual')

      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate"
      ).with(
        body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"}]}', # rubocop:disable Layout/LineLength
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      )
        .to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_id:, patient_id:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end

    it 'fails if $evaluate does not return 200' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate"
      ).with(
        body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"}]}', # rubocop:disable Layout/LineLength
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      )
        .to_return(status: 400, body: error_outcome.to_json)

      result = run(test, url:, measure_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/200/)
    end

    it 'fails if $evaluate does not return Parameters resource' do
      test_library = FHIR::Library.new
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate"
      ).with(
        body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"}]}', # rubocop:disable Layout/LineLength
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      )
        .to_return(status: 200, body: test_library.to_json, headers: {})

      result = run(test, url:, measure_id:, period_start:, period_end:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/Parameters/)
    end
  end

  describe 'Measure/$evaluate with reportType=population' do
    let(:test) { test_by_id(group, 'evaluate-measureid-body-default-reporttype') }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with correct parameter resource returned' do
      parameters_response = create_parameters_response('individual')

      stub_request(
        :post,
        "#{url}/Measure/$evaluate"
      ).with(
        body: '{"resourceType":"Parameters","parameter":[{"name":"measureId","valueString":"measure-EXM130-7.3.000"},{"name":"periodStart","valueDate":"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"}]}', # rubocop:disable Layout/LineLength
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      )
        .to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_id:, patient_id:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'Measure/$evaluate with reportType=subject' do
    let(:test) { test_by_id(group, 'evaluate-subject-reporttype-body') }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with correct parameter resource returned' do
      parameters_response = create_parameters_response('individual')

      stub_request(
        :post,
        "#{url}/Measure/$evaluate"
      ).with(
        body: '{"resourceType":"Parameters","parameter":[{"name":"measureId","valueString":"measure-EXM130-7.3.000"},{"name":"subject","valueString":"numer-EXM130"},{"name":"periodStart","valueDate":"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"}]}', # rubocop:disable Layout/LineLength
        headers: {
          'Accept' => 'application/fhir+json',
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      )
        .to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_id:, patient_id:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe '$evaluate output with multiple measures using Measure/$evaluate' do
    let(:test) { test_by_id(group, 'evaluate-multiple-measureids-no-reporttype') }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:additional_measures) { ['measure-EXM124-7.3.000'] }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with correct Parameters resource containing multiple bundles' do
      # Create a Parameters response with a single bundle containing multiple entries
      measure_report_first = FHIR::MeasureReport.new(
        status: 'complete', type: 'individual',
        measure: measure_id,
        period: { start: period_start, end: period_end }
      )
      measure_report_second = FHIR::MeasureReport.new(
        status: 'complete', type: 'individual',
        measure: additional_measures.first,
        period: { start: period_start, end: period_end }
      )
      bundle = FHIR::Bundle.new(type: 'collection', entry: [
                                  { resource: measure_report_first },
                                  { resource: measure_report_second }
                                ])
      parameters_response = FHIR::Parameters.new(parameter: [
                                                   { resource: bundle }
                                                 ])

      stub_request(
        :post,
        "#{url}/Measure/$evaluate"
      ).with(
        body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"},{"name":"measureId","valueString":"measure-EXM130-7.3.000"},{"name":"measureId","valueString":"measure-EXM124-7.3.000"}]}', # rubocop:disable Layout/LineLength
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      )
        .to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_id:, additional_measures:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end

    it 'fails if one of the multiple measures is invalid' do
      stub_request(
        :post,
        "#{url}/Measure/$evaluate"
      ).with(
        body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"},{"name":"measureId","valueString":"measure-EXM130-7.3.000"},{"name":"measureId","valueString":"INVALID_MEASURE_ID"}]}', # rubocop:disable Layout/LineLength
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      )
        .to_return(status: 404, body: error_outcome.to_json, headers: {})

      result = run(test, url:, measure_id:, additional_measures: [INVALID_MEASURE_ID], period_start:,
                         period_end:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/200/)
    end
  end

  describe '$evaluate output with multiple measures using Measure/$evaluate and reportType=subject' do
    let(:test) { test_by_id(group, 'evaluate-multiple-measureids-with-subject') }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:additional_measures) { ['measure-EXM124-7.3.000'] }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with correct Parameters resource containing multiple bundles' do
      # Create a Parameters response with a single bundle containing multiple entries
      measure_report_first = FHIR::MeasureReport.new(
        status: 'complete', type: 'individual',
        measure: measure_id,
        period: { start: period_start, end: period_end }
      )
      measure_report_second = FHIR::MeasureReport.new(
        status: 'complete', type: 'individual',
        measure: additional_measures.first,
        period: { start: period_start, end: period_end }
      )
      bundle = FHIR::Bundle.new(type: 'collection', entry: [
                                  { resource: measure_report_first },
                                  { resource: measure_report_second }
                                ])
      parameters_response = FHIR::Parameters.new(parameter: [
                                                   { resource: bundle }
                                                 ])

      stub_request(
        :post,
        "#{url}/Measure/$evaluate"
      ).with(
        body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"},{"name":"measureId","valueString":"measure-EXM130-7.3.000"},{"name":"measureId","valueString":"measure-EXM124-7.3.000"},{"name":"subject","valueString":"numer-EXM130"}]}', # rubocop:disable Layout/LineLength
        headers: {
          'Accept' => 'application/fhir+json',
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      )
        .to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_id:, additional_measures:, patient_id:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end

    it 'fails if one of the multiple measures is invalid' do
      stub_request(
        :post,
        "#{url}/Measure/$evaluate"
      ).with(
        body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"},{"name":"measureId","valueString":"measure-EXM130-7.3.000"},{"name":"measureId","valueString":"INVALID_MEASURE_ID"},{"name":"subject","valueString":"numer-EXM130"}]}', # rubocop:disable Layout/LineLength
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      )
        .to_return(status: 404, body: error_outcome.to_json, headers: {})

      result = run(test, url:, measure_id:, additional_measures: [INVALID_MEASURE_ID], patient_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/200/)
    end
  end

  ## TODO: write test for subjectGroup

  describe 'Measure/$evaluate with reportType=subject and subject Group reference' do
    let(:test) { test_by_id(group, 'evaluate-subjectgroup-reference') }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:group_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with correct Parameters resource' do
      parameters_response = create_parameters_response('individual')

      stub_request(
        :post,
        "#{url}/Measure/$evaluate"
      ).with(
        body: '{"resourceType":"Parameters","parameter":[{"name":"subject","valueString":"Group/numer-EXM130"},{"name":"measureId","valueString":"measure-EXM130-7.3.000"},{"name":"reportType","valueString":"subject"},{"name":"periodStart","valueDate":"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"}]}', # rubocop:disable Layout/LineLength
        headers: {
          'Accept' => 'application/fhir+json',
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      )
        .to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_id:, group_id:, period_start:, period_end:)
      puts result
      expect(result.result).to eq('pass')
    end
  end

  describe 'Measure/$evaluate reportType=subject fails for invalid measure id' do
    let(:test) { test_by_id(group, 'evaluate-invalid-measureid-subject') }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with correct Operation-Outcome returned' do
      stub_request(
        :post,
        "#{url}/Measure/$evaluate"
      ).with(body: '{"resourceType":"Parameters","parameter":[{"name":"measureId","valueString":"INVALID_MEASURE_ID"' \
                   '},{"name":"subject","valueString":"numer-EXM130"},{"name":"periodStart","valueDate":"2019-01-01"' \
                   '},{"name":"periodEnd","valueDate":"2019-12-31"}]}',
             headers: {
               'Accept' => 'application/fhir+json',
               'Content-Type' => 'application/fhir+json',
               'Origin' => 'http://example.com/fhir',
               'Referrer' => 'http://example.com/fhir'
             })
        .to_return(status: 404, body: error_outcome.to_json)

      result = run(test, url:, patient_id:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end

    it 'fails if server does not return 404 for invalid measure id' do
      stub_request(
        :post,
        "#{url}/Measure/$evaluate"
      ).with(body: '{"resourceType":"Parameters","parameter":[{"name":"measureId","valueString":"INVALID_MEASURE_ID"' \
                   '},{"name":"subject","valueString":"numer-EXM130"},{"name":"periodStart","valueDate":"2019-01-01"' \
                   '},{"name":"periodEnd","valueDate":"2019-12-31"}]}',
             headers: {
               'Accept' => 'application/fhir+json',
               'Content-Type' => 'application/fhir+json',
               'Origin' => 'http://example.com/fhir',
               'Referrer' => 'http://example.com/fhir'
             })
        .to_return(status: 200, body: error_outcome.to_json)

      result = run(test, url:, patient_id:, period_start:, period_end:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/404/)
    end
  end

  describe 'Measure/[id]/$evaluate fails for invalid measure ID' do
    let(:test) { test_by_id(group, 'evaluate-measureid-query-invalid-measureid') }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:params) { "periodStart=#{period_start}&periodEnd=#{period_end}&subject=Patient/#{patient_id}" }

    it 'passes with correct Operation-Outcome returned' do
      stub_request(
        :post,
        "#{url}/Measure/#{INVALID_MEASURE_ID}/$evaluate?#{params}"
      )
        .to_return(status: 404, body: error_outcome.to_json)

      result = run(test, url:, patient_id:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end

    it 'fails if server does not return 404 for invalid patient id' do
      stub_request(
        :post,
        "#{url}/Measure/#{INVALID_MEASURE_ID}/$evaluate?#{params}"
      )
        .to_return(status: 200, body: error_outcome.to_json)

      result = run(test, url:, patient_id:, period_start:, period_end:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/404/)
    end
  end

  describe 'Measure/$evaluate reportType=subject fails for invalid patient ID' do
    let(:test) { test_by_id(group, 'evaluate-invalid-patientid-subject-body') }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with correct Operation-Outcome returned' do
      stub_request(
        :post,
        "#{url}/Measure/$evaluate"
      ).with(body: '{"resourceType":"Parameters","parameter":[{"name":"measureId","valueString":"measure-EXM130-7.3' \
                   '.000"},{"name":"subject","valueString":"INVALID_PATIENT_ID"},{"name":"periodStart","valueDate":"' \
                   '2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"}]}',
             headers: {
               'Accept' => 'application/fhir+json',
               'Content-Type' => 'application/fhir+json',
               'Origin' => 'http://example.com/fhir',
               'Referrer' => 'http://example.com/fhir'
             })
        .to_return(status: 404, body: error_outcome.to_json)

      result = run(test, url:, measure_id:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end

    it 'fails if server does not return 400 for missing param' do
      stub_request(
        :post,
        "#{url}/Measure/$evaluate"
      ).with(body: '{"resourceType":"Parameters","parameter":[{"name":"measureId","valueString":"measure-EXM130-7.3.0' \
                   '00"},{"name":"subject","valueString":"INVALID_PATIENT_ID"},{"name":"periodStart","valueDate":' \
                   '"2019-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"}]}',
             headers: {
               'Accept' => 'application/fhir+json',
               'Content-Type' => 'application/fhir+json',
               'Origin' => 'http://example.com/fhir',
               'Referrer' => 'http://example.com/fhir'
             })
        .to_return(status: 200, body: error_outcome.to_json)

      result = run(test, url:, measure_id:, period_start:, period_end:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/404/)
    end
  end

  describe 'Measure/[id]/$evaluate reportType=subject fails for invalid patient ID' do
    let(:test) { test_by_id(group, 'evaluate-measureid-query-invalid-patientid') }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:params) do
      "periodStart=#{period_start}&periodEnd=#{period_end}&subject=#{INVALID_PATIENT_ID}"
    end

    it 'passes with correct Operation-Outcome returned' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate?#{params}"
      ).with(headers: {
               'Accept' => 'application/fhir+json',
               'Content-Type' => 'application/fhir+json',
               'Origin' => 'http://example.com/fhir',
               'Referrer' => 'http://example.com/fhir'
             })
        .to_return(status: 404, body: error_outcome.to_json)

      result = run(test, url:, measure_id:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end

    it 'fails if server does not return 400 for missing subject param' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate?#{params}"
      ).with(headers: {
               'Accept' => 'application/fhir+json',
               'Content-Type' => 'application/fhir+json',
               'Origin' => 'http://example.com/fhir',
               'Referrer' => 'http://example.com/fhir'
             })
        .to_return(status: 200, body: error_outcome.to_json)

      result = run(test, url:, measure_id:, period_start:, period_end:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/404/)
    end
  end

  describe 'Measure/[id]/$evaluate fails for missing subject query parameter (subject report type)' do
    let(:test) { test_by_id(group, 'evaluate-missing-subject-param') }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:params) do
      "periodStart=#{period_start}&periodEnd=#{period_end}" \
        '&reportType=subject'
    end

    it 'passes with correct Operation-Outcome returned' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate?#{params}"
      ).with(headers: {
               'Accept' => 'application/fhir+json',
               'Content-Type' => 'application/fhir+json',
               'Origin' => 'http://example.com/fhir',
               'Referrer' => 'http://example.com/fhir'
             })
        .to_return(status: 400, body: error_outcome.to_json)

      result = run(test, url:, measure_id:, period_start:,
                         period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'Measure/[id]/$evaluate reportType=subject fails for invalid reportType' do
    let(:test) { test_by_id(group, 'evaluate-measureid-query-invalid-reporttype') }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) { 'numer-EXM130' }
    let(:params) do
      'periodStart=2019-01-01&periodEnd=2019-12-31&subject=Patient/numer-EXM130&reportType=INVALID_REPORT_TYPE'
    end
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with correct Operation-Outcome returned' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate?#{params}"
      ).with(headers: {
               'Accept' => 'application/fhir+json',
               'Content-Type' => 'application/fhir+json',
               'Origin' => 'http://example.com/fhir',
               'Referrer' => 'http://example.com/fhir'
             })
        .to_return(status: 400, body: error_outcome.to_json)

      result = run(test, url:, measure_id:, patient_id:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end

    it 'fails if server does not return 400 for invalid reportType' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate?#{params}"
      ).with(headers: {
               'Accept' => 'application/fhir+json',
               'Content-Type' => 'application/fhir+json',
               'Origin' => 'http://example.com/fhir',
               'Referrer' => 'http://example.com/fhir'
             })
        .to_return(status: 200, body: error_outcome.to_json)

      result = run(test, url:, measure_id:, patient_id:, period_start:, period_end:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to match(/400/)
    end
  end

  describe 'Measure/$evaluate reportType=subject fails for invalid reportType' do
    let(:test) { test_by_id(group, 'evaluate-body-invalid-reporttype') }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with correct Operation-Outcome returned' do
      stub_request(
        :post,
        "#{url}/Measure/$evaluate"
      ).with(body: '{"resourceType":"Parameters","parameter":[{"name":"measureId","valueString":"measure-EXM130-7.' \
                   '3.000"},{"name":"subject","valueString":"numer-EXM130"},{"name":"periodStart","valueDate":"2019' \
                   '-01-01"},{"name":"periodEnd","valueDate":"2019-12-31"},{"name":"reportType","valueString":"' \
                   'INVALID_REPORT_TYPE"}]}',
             headers: {
               'Accept' => 'application/fhir+json',
               'Content-Type' => 'application/fhir+json',
               'Origin' => 'http://example.com/fhir',
               'Referrer' => 'http://example.com/fhir'
             })
        .to_return(status: 400, body: error_outcome.to_json)

      result = run(test, url:, measure_id:, patient_id:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'Measure/[id]/$evaluate reportType=subject fails for missing periodEnd parameter in input' do
    let(:test) { test_by_id(group, 'evaluate-measureid-query-missing-periodend') }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:params) { "periodStart=#{period_start}&subject=Patient/#{patient_id}" }

    it 'passes with correct Operation-Outcome returned' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$evaluate?#{params}"
      )
        .to_return(status: 400, body: error_outcome.to_json)

      result = run(test, url:, measure_id:, patient_id:, period_start:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'Measure/$evaluate reportType=subject fails for missing periodEnd parameter' do
    let(:test) { test_by_id(group, 'evaluate-body-missing-periodend') }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:patient_id) { 'numer-EXM130' }
    let(:period_start) { '2019-01-01' }

    it 'passes with correct Operation-Outcome returned' do
      stub_request(
        :post,
        "#{url}/Measure/$evaluate"
      ).with(body: '{"resourceType":"Parameters","parameter":[{"name":"measureId","valueString":"measure-EXM130-7' \
                   '.3.000"},{"name":"subject","valueString":"numer-EXM130"},{"name":"periodStart","valueDate":"20' \
                   '19-01-01"}]}',
             headers: {
               'Accept' => 'application/fhir+json',
               'Content-Type' => 'application/fhir+json',
               'Origin' => 'http://example.com/fhir',
               'Referrer' => 'http://example.com/fhir'
             })
        .to_return(status: 400, body: error_outcome.to_json)

      result = run(test, url:, measure_id:, patient_id:, period_start:)
      expect(result.result).to eq('pass')
    end
  end
end
