# frozen_string_literal: true

INVALID_MEASURE_ID = 'INVALID_MEASURE_ID'
INVALID_START_DATE = 'INVALID_START_DATE'

RSpec.describe DEQMTestKit::EvaluateV1 do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('deqm_v100') }
  let(:evaluate_group) { suite.groups[1] }
  let(:base_tests) { evaluate_group.groups[0] }
  let(:subject_tests) { evaluate_group.groups[1] }
  let(:subject_group_tests) { evaluate_group.groups[2] }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite.id) }
  let(:url) { 'http://example.com/fhir' }
  let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }

  # Helper method to create a valid Parameters resource
  def create_parameters_response(measure_urls:, bundle_count: 1, report_type: 'summary') # rubocop:disable Metrics/MethodLength
    measure_reports = measure_urls.map do |url|
      FHIR::MeasureReport.new(
        status: 'complete', type: report_type,
        measure: url,
        period: { start: '2019-01-01', end: '2019-12-31' }
      )
    end

    bundles = bundle_count.times.map do
      FHIR::Bundle.new(type: 'transaction', entry: measure_reports.map { |mr| { resource: mr } })
    end

    FHIR::Parameters.new(parameter: bundles.map do |bundle|
      {
        name: 'return',
        resource: bundle
      }
    end)
  end

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def create_parameters_request(options)
    parameters = options[:measure_urls].map { |measure_url| { name: 'measureUrl', valueCanonical: measure_url } }
    if options[:patient_id_list]
      parameters << {
        name: 'subjectGroup',
        resource: {
          resourceType: 'Group',
          id: 'test-group-subjectGroup',
          type: 'person',
          actual: true,
          member: options[:patient_id_list].map { |patient_id| { entity: { reference: "Patient/#{patient_id}" } } }
        }
      }
    end
    parameters << { name: 'subject', valueString: "Patient/#{options[:patient_id]}" } if options[:patient_id]
    parameters << { name: 'subject', valueString: "Group/#{options[:group_id]}" } if options[:group_id]
    parameters << { name: 'periodStart', valueDate: options[:period_start] }
    parameters << { name: 'periodEnd', valueDate: options[:period_end] }
    parameters << { name: 'reportType', valueCode: options[:report_type] } if options[:report_type]

    {
      resourceType: 'Parameters',
      parameter: parameters
    }
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(test_session_id: test_session.id, name:, value:, type: 'text')
    end
    Inferno::TestRunner.new(test_session:, test_run:).run(runnable)
  end

  describe 'GET Measure/$evaluate with one measureUrl and required params' do
    let(:test) { test_by_id(base_tests, 'evaluate-one-measure-summary-get') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with correct FHIR Parameters resource returned' do
      parameters_response = create_parameters_response(measure_urls: [measure_url])

      stub_request(
        :get,
        "#{url}/Measure/$evaluate"
      ).with(
        query: {
          measureUrl: measure_url,
          periodStart: period_start,
          periodEnd: period_end
        },
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_url:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$evaluate with one measureUrl and required params' do
    let(:test) { test_by_id(base_tests, 'evaluate-one-measure-summary-post') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with correct FHIR Parameters resource returned' do
      parameters_request = create_parameters_request(measure_urls: [measure_url], period_start:, period_end:)
      parameters_response = create_parameters_response(measure_urls: [measure_url])

      stub_request(
        :post,
        "#{url}/Measure/$evaluate"
      ).with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_url:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'GET Measure/$evaluate with two measureUrls and required params' do
    let(:test) { test_by_id(base_tests, 'evaluate-two-measure-summary-get') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:additional_measure_url) { 'http://example.com/Measure/measure-EXM124' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with correct FHIR Parameters resource returned' do
      parameters_response = create_parameters_response(measure_urls: [measure_url, additional_measure_url])
      query = URI.encode_www_form([
                                    ['measureUrl', measure_url],
                                    ['measureUrl', additional_measure_url],
                                    ['periodStart', period_start],
                                    ['periodEnd', period_end]
                                  ])

      stub_request(
        :get,
        "#{url}/Measure/$evaluate"
      ).with(
        query: query,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_url:, additional_measure_url:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$evaluate with two measureUrls and required params' do
    let(:test) { test_by_id(base_tests, 'evaluate-two-measure-summary-post') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:additional_measure_url) { 'http://example.com/Measure/measure-EXM124' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with correct FHIR Parameters resource returned' do
      parameters_response = create_parameters_response(measure_urls: [measure_url, additional_measure_url])
      parameters_request = create_parameters_request(
        measure_urls: [measure_url, additional_measure_url],
        period_start:,
        period_end:
      )

      stub_request(
        :post,
        "#{url}/Measure/$evaluate"
      ).with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_url:, additional_measure_url:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'GET Measure/$evaluate with one measureUrl and subject=Patient/patientId' do
    let(:test) { test_by_id(subject_tests, 'evaluate-one-measure-get-subject-patient') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:patient_id) { 'patient-1' }

    it 'passes with correct FHIR Parameters resource returned' do
      parameters_response = create_parameters_response(measure_urls: [measure_url], report_type: 'individual')

      stub_request(:get, "#{url}/Measure/$evaluate").with(
        query: {
          measureUrl: measure_url,
          periodStart: period_start,
          periodEnd: period_end,
          subject: "Patient/#{patient_id}"
        },
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => url,
          'Referrer' => url
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_url:, period_start:, period_end:, patient_id:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$evaluate with one measureUrl and subject=Patient/patientId' do
    let(:test) { test_by_id(subject_tests, 'evaluate-one-measure-post-subject-patient') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:patient_id) { 'patient-1' }

    it 'passes with correct FHIR Parameters resource returned' do
      parameters_request = create_parameters_request(
        measure_urls: [measure_url], period_start:, period_end:, patient_id:
      )
      parameters_response = create_parameters_response(measure_urls: [measure_url], report_type: 'individual')

      stub_request(:post, "#{url}/Measure/$evaluate").with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => url,
          'Referrer' => url
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_url:, period_start:, period_end:, patient_id:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$evaluate with one measureUrl, subject=Patient/patientId, and reportType=summary' do
    let(:test) { test_by_id(subject_tests, 'evaluate-one-measure-summary-post-subject-patient') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:patient_id) { 'patient-1' }

    it 'passes with correct FHIR Parameters resource returned' do
      parameters_request = create_parameters_request(
        measure_urls: [measure_url], period_start:, period_end:, patient_id:, report_type: 'summary'
      )
      parameters_response = create_parameters_response(measure_urls: [measure_url])

      stub_request(:post, "#{url}/Measure/$evaluate").with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => url,
          'Referrer' => url
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_url:, period_start:, period_end:, patient_id:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'GET Measure/$evaluate with two measureUrls and subject=Patient/patientId' do
    let(:test) { test_by_id(subject_tests, 'evaluate-two-measure-get-subject-patient') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:additional_measure_url) { 'http://example.com/Measure/measure-EXM124' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:patient_id) { 'patient-1' }

    it 'passes with correct FHIR Parameters resource returned' do
      measure_urls = [measure_url, additional_measure_url]
      parameters_response = create_parameters_response(measure_urls:, report_type: 'individual')
      query = URI.encode_www_form([
                                    ['measureUrl', measure_url],
                                    ['measureUrl', additional_measure_url],
                                    ['periodStart', period_start],
                                    ['periodEnd', period_end],
                                    ['subject', "Patient/#{patient_id}"]
                                  ])

      stub_request(:get, "#{url}/Measure/$evaluate").with(
        query: query,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => url,
          'Referrer' => url
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_url:, additional_measure_url:, period_start:, period_end:, patient_id:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$evaluate with two measureUrls and subject=Patient/patientId' do
    let(:test) { test_by_id(subject_tests, 'evaluate-two-measure-post-subject-patient') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:additional_measure_url) { 'http://example.com/Measure/measure-EXM124' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:patient_id) { 'patient-1' }

    it 'passes with correct FHIR Parameters resource returned' do
      measure_urls = [measure_url, additional_measure_url]
      parameters_request = create_parameters_request(measure_urls:, period_start:, period_end:, patient_id:)
      parameters_response = create_parameters_response(measure_urls:, report_type: 'individual')

      stub_request(:post, "#{url}/Measure/$evaluate").with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => url,
          'Referrer' => url
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_url:, additional_measure_url:, period_start:, period_end:, patient_id:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'GET Measure/$evaluate with one measureUrl and subject=Group/groupId' do
    let(:test) { test_by_id(subject_tests, 'evaluate-one-measure-get-subject-group-reference') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:group_id) { 'group-1' }

    it 'passes with correct FHIR Parameters resource returned' do
      parameters_response = create_parameters_response(measure_urls: [measure_url])

      stub_request(:get, "#{url}/Measure/$evaluate").with(
        query: {
          measureUrl: measure_url,
          periodStart: period_start,
          periodEnd: period_end,
          subject: "Group/#{group_id}"
        },
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => url,
          'Referrer' => url
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_url:, period_start:, period_end:, group_id:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$evaluate with one measureUrl and subject=Group/groupId' do
    let(:test) { test_by_id(subject_tests, 'evaluate-one-measure-post-subject-group-reference') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:group_id) { 'group-1' }

    it 'passes with correct FHIR Parameters resource returned' do
      parameters_request = create_parameters_request(measure_urls: [measure_url], period_start:, period_end:, group_id:)
      parameters_response = create_parameters_response(measure_urls: [measure_url])

      stub_request(:post, "#{url}/Measure/$evaluate").with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => url,
          'Referrer' => url
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_url:, period_start:, period_end:, group_id:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$evaluate with one measureUrl, subject=Group/groupId, and reportType=individual' do
    let(:test) { test_by_id(subject_tests, 'evaluate-one-measure-individual-post-subject-group-reference') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:group_id) { 'group-1' }
    it 'passes when one Bundle with an individual MeasureReport is returned per Group member' do
      group = FHIR::Group.new(
        id: group_id,
        type: 'person',
        actual: true,
        member: [
          { entity: { reference: 'Patient/patient-1' } },
          { entity: { reference: 'Patient/patient-2' } }
        ]
      )
      parameters_request = create_parameters_request(
        measure_urls: [measure_url], period_start:, period_end:, group_id:, report_type: 'individual'
      )
      parameters_response = create_parameters_response(
        measure_urls: [measure_url], bundle_count: group.member.length, report_type: 'individual'
      )

      stub_request(:get, "#{url}/Group/#{group_id}").to_return(status: 200, body: group.to_json, headers: {})
      stub_request(:post, "#{url}/Measure/$evaluate").with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => url,
          'Referrer' => url
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_url:, period_start:, period_end:, group_id:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'GET Measure/$evaluate with two measureUrls and subject=Group/groupId' do
    let(:test) { test_by_id(subject_tests, 'evaluate-two-measure-get-subject-group-reference') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:additional_measure_url) { 'http://example.com/Measure/measure-EXM124' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:group_id) { 'group-1' }

    it 'passes with correct FHIR Parameters resource returned' do
      measure_urls = [measure_url, additional_measure_url]
      parameters_response = create_parameters_response(measure_urls:)
      query = URI.encode_www_form([
                                    ['measureUrl', measure_url],
                                    ['measureUrl', additional_measure_url],
                                    ['periodStart', period_start],
                                    ['periodEnd', period_end],
                                    ['subject', "Group/#{group_id}"]
                                  ])

      stub_request(:get, "#{url}/Measure/$evaluate").with(
        query: query,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => url,
          'Referrer' => url
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_url:, additional_measure_url:, period_start:, period_end:, group_id:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$evaluate with two measureUrls and subject=Group/groupId' do
    let(:test) { test_by_id(subject_tests, 'evaluate-two-measure-post-subject-group-reference') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:additional_measure_url) { 'http://example.com/Measure/measure-EXM124' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:group_id) { 'group-1' }

    it 'passes with correct FHIR Parameters resource returned' do
      measure_urls = [measure_url, additional_measure_url]
      parameters_request = create_parameters_request(measure_urls:, period_start:, period_end:, group_id:)
      parameters_response = create_parameters_response(measure_urls:)

      stub_request(:post, "#{url}/Measure/$evaluate").with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => url,
          'Referrer' => url
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_url:, additional_measure_url:, period_start:, period_end:, group_id:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$evaluate with one measureUrl and subjectGroup' do
    let(:test) { test_by_id(subject_group_tests, 'evaluate-one-measure-summary-post-subject-group') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:patient_ids) { 'patient-1, patient-2' }

    it 'passes with correct FHIR Parameters resource returned' do
      patient_id_list = patient_ids.split(',').map(&:strip).reject(&:empty?)
      parameters_request = create_parameters_request(
        measure_urls: [measure_url], period_start:, period_end:, patient_id_list:
      )
      parameters_response = create_parameters_response(measure_urls: [measure_url])

      stub_request(
        :post,
        "#{url}/Measure/$evaluate"
      ).with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_url:, period_start:, period_end:, patient_ids:)
      expect(result.result).to eq('pass')
    end

    it 'fails if result has incorrect number of measure reports' do
      patient_id_list = patient_ids.split(',').map(&:strip).reject(&:empty?)
      parameters_request = create_parameters_request(
        measure_urls: [measure_url], period_start:, period_end:, patient_id_list:
      )
      parameters_response = create_parameters_response(measure_urls: [measure_url, measure_url])

      stub_request(:post, "#{url}/Measure/$evaluate").with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_url:, period_start:, period_end:, patient_ids:)
      expect(result.result).to eq('fail')
    end

    it 'fails if result has incorrect number of bundles' do
      patient_id_list = patient_ids.split(',').map(&:strip).reject(&:empty?)
      parameters_request = create_parameters_request(
        measure_urls: [measure_url], period_start:, period_end:, patient_id_list:
      )
      parameters_response = create_parameters_response(measure_urls: [measure_url], bundle_count: 2)

      stub_request(:post, "#{url}/Measure/$evaluate").with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_url:, period_start:, period_end:, patient_ids:)
      expect(result.result).to eq('fail')
    end
  end

  describe 'POST Measure/$evaluate with two measureUrls and subjectGroup' do
    let(:test) { test_by_id(subject_group_tests, 'evaluate-two-measure-summary-post-subject-group') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:additional_measure_url) { 'http://example.com/Measure/measure-EXM124' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:patient_ids) { 'patient-1, patient-2' }

    it 'passes with correct FHIR Parameters resource returned' do
      measure_urls = [measure_url, additional_measure_url]
      patient_id_list = patient_ids.split(',').map(&:strip).reject(&:empty?)
      parameters_request = create_parameters_request(
        measure_urls:, period_start:, period_end:, patient_id_list:
      )
      parameters_response = create_parameters_response(measure_urls:)

      stub_request(:post, "#{url}/Measure/$evaluate").with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_url:, additional_measure_url:, period_start:, period_end:, patient_ids:)
      expect(result.result).to eq('pass')
    end

    it 'fails if result has incorrect number of measure reports' do
      measure_urls = [measure_url, additional_measure_url]
      patient_id_list = patient_ids.split(',').map(&:strip).reject(&:empty?)
      parameters_request = create_parameters_request(
        measure_urls:, period_start:, period_end:, patient_id_list:
      )
      parameters_response = create_parameters_response(measure_urls: [measure_url])

      stub_request(:post, "#{url}/Measure/$evaluate").with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_url:, additional_measure_url:, period_start:, period_end:, patient_ids:)
      expect(result.result).to eq('fail')
    end

    it 'fails if result has incorrect number of bundles' do
      measure_urls = [measure_url, additional_measure_url]
      patient_id_list = patient_ids.split(',').map(&:strip).reject(&:empty?)
      parameters_request = create_parameters_request(
        measure_urls:, period_start:, period_end:, patient_id_list:
      )
      parameters_response = create_parameters_response(measure_urls:, bundle_count: 2)

      stub_request(:post, "#{url}/Measure/$evaluate").with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 200, body: parameters_response.to_json, headers: {})

      result = run(test, url:, measure_url:, additional_measure_url:, period_start:, period_end:, patient_ids:)
      expect(result.result).to eq('fail')
    end
  end

  describe 'POST Measure/$evaluate with one measureUrl, subjectGroup, and reportType=individual' do
    let(:test) { test_by_id(subject_group_tests, 'evaluate-one-measure-individual-post-subject-group') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:patient_ids) { 'patient-1, patient-2' }

    it 'passes with correct FHIR Parameters resource returned' do
      patient_id_list = patient_ids.split(',').map(&:strip).reject(&:empty?)
      parameters_request = create_parameters_request(
        measure_urls: [measure_url], period_start:, period_end:, patient_id_list:, report_type: 'individual'
      )
      parameters_response = create_parameters_response(
        measure_urls: [measure_url], bundle_count: patient_id_list.length, report_type: 'individual'
      )

      stub_request(:post, "#{url}/Measure/$evaluate").with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(
        status: 200, body: parameters_response.to_json, headers: {}
      )

      result = run(test, url:, measure_url:, period_start:, period_end:, patient_ids:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$evaluate with two measureUrls, subjectGroup, and reportType=individual' do
    let(:test) { test_by_id(subject_group_tests, 'evaluate-two-measure-individual-post-subject-group') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:additional_measure_url) { 'http://example.com/Measure/measure-EXM124' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:patient_ids) { 'patient-1, patient-2' }

    it 'passes with correct FHIR Parameters resource returned' do
      measure_urls = [measure_url, additional_measure_url]
      patient_id_list = patient_ids.split(',').map(&:strip).reject(&:empty?)
      parameters_request = create_parameters_request(
        measure_urls:, period_start:, period_end:, patient_id_list:, report_type: 'individual'
      )
      parameters_response = create_parameters_response(
        measure_urls:, bundle_count: patient_id_list.length, report_type: 'individual'
      )

      stub_request(:post, "#{url}/Measure/$evaluate").with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(
        status: 200, body: parameters_response.to_json, headers: {}
      )

      result = run(test, url:, measure_url:, additional_measure_url:, period_start:, period_end:, patient_ids:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'GET Measure/$evaluate missing periodEnd' do
    let(:test) { test_by_id(base_tests, 'evaluate-missing-period-end-get-fail') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:period_start) { '2019-01-01' }

    it 'passes with HTTP 400 error and correct OperationOutcome returned' do
      stub_request(
        :get,
        "#{url}/Measure/$evaluate"
      ).with(
        query: {
          measureUrl: measure_url,
          periodStart: period_start
          # periodEnd intentionally omitted
        },
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 400, body: error_outcome.to_json, headers: {})

      result = run(test, url:, measure_url:, period_start:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$evaluate missing periodEnd' do
    let(:test) { test_by_id(base_tests, 'evaluate-missing-period-end-post-fail') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:period_start) { '2019-01-01' }

    it 'passes with HTTP 400 error and correct OperationOutcome returned' do
      parameters_request = {
        resourceType: 'Parameters',
        parameter: [
          { name: 'measureUrl', valueCanonical: measure_url },
          { name: 'periodStart', valueDate: period_start }
          # periodEnd intentionally omitted
        ]
      }

      stub_request(
        :post,
        "#{url}/Measure/$evaluate"
      ).with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 400, body: error_outcome.to_json, headers: {})

      result = run(test, url:, measure_url:, period_start:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'GET Measure/$evaluate missing periodStart' do
    let(:test) { test_by_id(base_tests, 'evaluate-missing-period-start-get-fail') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:period_end) { '2019-12-31' }

    it 'passes with HTTP 400 error and correct OperationOutcome returned' do
      stub_request(
        :get,
        "#{url}/Measure/$evaluate"
      ).with(
        query: {
          measureUrl: measure_url,
          periodEnd: period_end
          # periodStart intentionally omitted
        },
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 400, body: error_outcome.to_json, headers: {})

      result = run(test, url:, measure_url:, period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$evaluate missing periodStart' do
    let(:test) { test_by_id(base_tests, 'evaluate-missing-period-start-post-fail') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:period_end) { '2019-12-31' }

    it 'passes with HTTP 400 error and correct OperationOutcome returned' do
      parameters_request = {
        resourceType: 'Parameters',
        parameter: [
          { name: 'measureUrl', valueCanonical: measure_url },
          { name: 'periodEnd', valueDate: period_end }
          # periodStart intentionally omitted
        ]
      }

      stub_request(
        :post,
        "#{url}/Measure/$evaluate"
      ).with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 400, body: error_outcome.to_json, headers: {})

      result = run(test, url:, measure_url:, period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'GET Measure/$evaluate missing measureUrl' do
    let(:test) { test_by_id(base_tests, 'evaluate-missing-measure-url-get-fail') }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with HTTP 400 error and correct OperationOutcome returned' do
      stub_request(
        :get,
        "#{url}/Measure/$evaluate"
      ).with(
        query: {
          periodStart: period_start,
          periodEnd: period_end
          # measureUrl intentionally omitted
        },
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 400, body: error_outcome.to_json, headers: {})

      result = run(test, url:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$evaluate missing measureUrl' do
    let(:test) { test_by_id(base_tests, 'evaluate-missing-measure-url-post-fail') }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with HTTP 400 error and correct OperationOutcome returned' do
      parameters_request = {
        resourceType: 'Parameters',
        parameter: [
          { name: 'periodStart', valueDate: period_start },
          { name: 'periodEnd', valueDate: period_end }
          # measureUrl intentionally omitted
        ]
      }

      stub_request(
        :post,
        "#{url}/Measure/$evaluate"
      ).with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 400, body: error_outcome.to_json, headers: {})

      result = run(test, url:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'GET Measure/$evaluate with both subject and subjectGroup' do
    let(:test) { test_by_id(base_tests, 'evaluate-subject-and-subject-group-get-fail') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:patient_id) { 'test-patient' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with HTTP 400 error and correct OperationOutcome returned' do
      stub_request(
        :get,
        "#{url}/Measure/$evaluate"
      ).with(
        query: {
          measureUrl: measure_url,
          subject: patient_id,
          subjectGroup: 'Group/test-group',
          periodStart: period_start,
          periodEnd: period_end
        },
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 400, body: error_outcome.to_json, headers: {})

      result = run(test, url:, measure_url:, patient_id:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end
  end

  describe 'POST Measure/$evaluate with both subject and subjectGroup' do
    let(:test) { test_by_id(base_tests, 'evaluate-subject-and-subject-group-post-fail') }
    let(:measure_url) { 'http://example.com/Measure/measure-EXM130' }
    let(:patient_id) { 'test-patient' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes with HTTP 400 error and correct OperationOutcome returned' do
      parameters_request = {
        resourceType: 'Parameters',
        parameter: [
          { name: 'measureUrl', valueCanonical: measure_url },
          { name: 'subject', valueString: patient_id },
          {
            name: 'subjectGroup',
            resource: {
              resourceType: 'Group',
              id: 'test-group',
              member: [
                {
                  entity: {
                    reference: "Patient/#{patient_id}"
                  }
                }
              ]
            }
          },
          { name: 'periodStart', valueDate: period_start },
          { name: 'periodEnd', valueDate: period_end }
        ]
      }

      stub_request(
        :post,
        "#{url}/Measure/$evaluate"
      ).with(
        body: parameters_request.to_json,
        headers: {
          'Content-Type' => 'application/fhir+json',
          'Origin' => 'http://example.com/fhir',
          'Referrer' => 'http://example.com/fhir'
        }
      ).to_return(status: 400, body: error_outcome.to_json, headers: {})

      result = run(test, url:, measure_url:, patient_id:, period_start:, period_end:)
      expect(result.result).to eq('pass')
    end
  end
end
