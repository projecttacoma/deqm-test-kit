# frozen_string_literal: true

RSpec.describe DEQMTestKit::FHIRQueries do
  let(:suite) { Inferno::Repositories::TestSuites.new.find('deqm_v300') }
  let(:group) { suite.groups[3] }
  let(:session_data_repo) { Inferno::Repositories::SessionData.new }
  let(:test_session) { repo_create(:test_session, test_suite_id: suite.id) }
  let(:url) { 'http://example.com/fhir' }
  let(:error_outcome) { FHIR::OperationOutcome.new(issue: [{ severity: 'error' }]) }
  let(:test_condition_response) { FHIR::Bundle.new(total: 1, entry: [{ resource: { id: 'test-condition' } }]) }

  # rubocop:disable Layout/LineLength
  let(:test_library_response) do
    FHIR::Library.new(dataRequirement: [{ type: 'Condition',
                                          extension: [{ url: 'http://hl7.org/fhir/us/cqfmeasures/StructureDefinition/cqfm-fhirQueryPattern',
                                                        valueString: '/Condition?code:in=testvs&subject=Patient/{{context.patientId}}' },
                                                      { url: 'http://hl7.org/fhir/us/cqfmeasures/StructureDefinition/cqfm-fhirQueryPattern',
                                                        valueString: '/Condition?code:in=testvs2&subject=Patient/{{context.patientId}}' }] }])
    # rubocop:enable Layout/LineLength
  end

  let(:test_library_response_no_extension) do
    FHIR::Library.new(dataRequirement: [{ type: 'Condition' }])
  end

  let(:test_patient_response) do
    FHIR::Bundle.new(total: 1, entry: [{ resource: { id: 'test-patient' } }])
  end

  def run(runnable, inputs = {})
    test_run_params = { test_session_id: test_session.id }.merge(runnable.reference_hash)
    test_run = Inferno::Repositories::TestRuns.new.create(test_run_params)
    inputs.each do |name, value|
      session_data_repo.save(test_session_id: test_session.id, name:, value:, type: 'text')
    end
    Inferno::TestRunner.new(test_session:, test_run:).run(runnable)
  end

  describe 'FHIR queries with successful $data-requirements request (all patients)' do
    let(:test) { test_by_id(group, 'fhir-queries-all-patients-from-data-requirements') }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:condition_id) { 'test-condition' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }

    it 'passes if the FHIR queries does not use FHIR query pattern, returns 200 and valid JSON' do
      stub_request(:get, "#{url}/Condition").with(headers: { 'Accept' => 'application/fhir+json',
                                                             'Content-Type' => 'application/fhir+json',
                                                             'Origin' => 'http://example.com/fhir',
                                                             'Referrer' => 'http://example.com/fhir' })
                                            .to_return(status: 200, body: test_condition_response.to_json)

      stub_request(:get, "#{url}/Patient").with(headers: { 'Accept' => 'application/fhir+json',
                                                           'Content-Type' => 'application/fhir+json',
                                                           'Origin' => 'http://example.com/fhir',
                                                           'Referrer' => 'http://example.com/fhir' })
                                          .to_return(status: 200, body: test_patient_response.to_json)

      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$data-requirements"
      ).with(body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},' \
                   '{"name":"periodEnd","valueDate":"2019-12-31"}]}',
             headers: { 'Accept' => 'application/fhir+json',
                        'Content-Type' => 'application/fhir+json',
                        'Origin' => 'http://example.com/fhir',
                        'Referrer' => 'http://example.com/fhir' })
        .to_return(status: 200, body: test_library_response.to_json)

      result = run(test, url:, measure_id:, data_requirements_server_url: url)
      expect(result.result).to eq('pass')
    end

    it 'passes if the FHIR queries uses FHIR query pattern, returns 200 and valid JSON' do
      test_patient_response = FHIR::Bundle.new(total: 1, entry: [{ resource: { id: 'test-patient' } }])

      stub_request(:get, "#{url}/Condition?code:in=testvs")
        .with(headers: { 'Accept' => 'application/fhir+json',
                         'Content-Type' => 'application/fhir+json',
                         'Origin' => 'http://example.com/fhir',
                         'Referrer' => 'http://example.com/fhir' })
        .to_return(status: 200, body: test_condition_response.to_json)

      stub_request(:get, "#{url}/Condition?code:in=testvs2")
        .with(headers: { 'Accept' => 'application/fhir+json',
                         'Content-Type' => 'application/fhir+json',
                         'Origin' => 'http://example.com/fhir',
                         'Referrer' => 'http://example.com/fhir' })
        .to_return(status: 200, body: test_condition_response.to_json)

      stub_request(:get, "#{url}/Patient")
        .with(headers: { 'Accept' => 'application/fhir+json',
                         'Content-Type' => 'application/fhir+json',
                         'Origin' => 'http://example.com/fhir',
                         'Referrer' => 'http://example.com/fhir' })
        .to_return(status: 200, body: test_patient_response.to_json)

      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$data-requirements"
      ).with(body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},' \
                   '{"name":"periodEnd","valueDate":"2019-12-31"}]}',
             headers: { 'Accept' => 'application/fhir+json',
                        'Content-Type' => 'application/fhir+json',
                        'Origin' => 'http://example.com/fhir',
                        'Referrer' => 'http://example.com/fhir' })
        .to_return(status: 200, body: test_library_response.to_json)

      result = run(test, url:, measure_id:, use_fqp_extension: 'true', data_requirements_server_url: url)
      expect(result.result).to eq('pass')
    end

    it 'fails if use FHIR query pattern is toggled, but no fqp extension present' do
      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$data-requirements"
      ).with(body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},' \
                   '{"name":"periodEnd","valueDate":"2019-12-31"}]}',
             headers: { 'Accept' => 'application/fhir+json',
                        'Content-Type' => 'application/fhir+json',
                        'Origin' => 'http://example.com/fhir',
                        'Referrer' => 'http://example.com/fhir' })
        .to_return(status: 200, body: test_library_response_no_extension.to_json)

      result = run(test, url:, measure_id:, use_fqp_extension: 'true', data_requirements_server_url: url)
      expect(result.result).to eq('fail')
      # rubocop:disable Layout/LineLength

      expect(result.result_message).to eq('"Use FHIR query pattern" is true, but no FHIR Query Pattern Extension found on DataRequirements')
      # rubocop:enable Layout/LineLength
    end

    it 'fails if a single FHIR query returns 500 and use FHIR query extension set to false' do
      stub_request(:get, "#{url}/Condition").with(headers: { 'Accept' => 'application/fhir+json',
                                                             'Content-Type' => 'application/fhir+json',
                                                             'Origin' => 'http://example.com/fhir',
                                                             'Referrer' => 'http://example.com/fhir' })
                                            .to_return(status: 200, body: test_condition_response.to_json)

      stub_request(:get, "#{url}/Patient").with(headers: {               'Accept' => 'application/fhir+json',
                                                                         'Content-Type' => 'application/fhir+json',
                                                                         'Origin' => 'http://example.com/fhir',
                                                                         'Referrer' => 'http://example.com/fhir' })
                                          .to_return(status: 500, body: error_outcome.to_json)

      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$data-requirements"
      ).with(body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},' \
                   '{"name":"periodEnd","valueDate":"2019-12-31"}]}',
             headers: { 'Accept' => 'application/fhir+json',
                        'Content-Type' => 'application/fhir+json',
                        'Origin' => 'http://example.com/fhir',
                        'Referrer' => 'http://example.com/fhir' })
        .to_return(status: 200, body: test_library_response.to_json)

      result = run(test, url:, measure_id:, data_requirements_server_url: url)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Expected response code 200, received: 500 for query: /Patient')
    end

    it 'fails if a single FHIR query returns 500 and use FHIR query extension set to true' do
      stub_request(:get, "#{url}/Condition?code:in=testvs")
        .with(headers: { 'Accept' => 'application/fhir+json',
                         'Content-Type' => 'application/fhir+json',
                         'Origin' => 'http://example.com/fhir',
                         'Referrer' => 'http://example.com/fhir' })
        .to_return(status: 200, body: test_condition_response.to_json)

      stub_request(:get, "#{url}/Condition?code:in=testvs2")
        .with(headers: { 'Accept' => 'application/fhir+json',
                         'Content-Type' => 'application/fhir+json',
                         'Origin' => 'http://example.com/fhir',
                         'Referrer' => 'http://example.com/fhir' })
        .to_return(status: 500, body: error_outcome.to_json)

      stub_request(:get, "#{url}/Patient")
        .with(headers: { 'Accept' => 'application/fhir+json',
                         'Content-Type' => 'application/fhir+json',
                         'Origin' => 'http://example.com/fhir',
                         'Referrer' => 'http://example.com/fhir' })
        .to_return(status: 200, body: test_patient_response.to_json)

      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$data-requirements"
      ).with(body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},' \
                   '{"name":"periodEnd","valueDate":"2019-12-31"}]}',
             headers: { 'Accept' => 'application/fhir+json',
                        'Content-Type' => 'application/fhir+json',
                        'Origin' => 'http://example.com/fhir',
                        'Referrer' => 'http://example.com/fhir' })
        .to_return(status: 200, body: test_library_response.to_json)

      result = run(test, url:, measure_id:, use_fqp_extension: 'true', data_requirements_server_url: url)
      expect(result.result).to eq('fail')
      # rubocop:disable Layout/LineLength

      expect(result.result_message).to eq('Expected response code 200, received: 500 for query: /Condition?code%3Ain=testvs2')
      # rubocop:enable Layout/LineLength
    end
  end

  describe 'FHIR queries with successful $data-requirements request (single patient)' do
    let(:test) { test_by_id(group, 'fhir-queries-single-patient-from-data-requirements') }
    let(:measure_id) { 'measure-EXM130-7.3.000' }
    let(:condition_id) { 'test-condition' }
    let(:period_start) { '2019-01-01' }
    let(:period_end) { '2019-12-31' }
    let(:patient_id) { 'test-patient' }

    it 'should pass with proper patient ID substitution' do
      stub_request(:get, "#{url}/Condition?code:in=testvs&subject=Patient/#{patient_id}")
        .with(headers: { 'Accept' => 'application/fhir+json',
                         'Content-Type' => 'application/fhir+json',
                         'Origin' => 'http://example.com/fhir',
                         'Referrer' => 'http://example.com/fhir' })
        .to_return(status: 200, body: test_condition_response.to_json)

      stub_request(:get, "#{url}/Condition?code:in=testvs2&subject=Patient/#{patient_id}")
        .with(headers: { 'Accept' => 'application/fhir+json',
                         'Content-Type' => 'application/fhir+json',
                         'Origin' => 'http://example.com/fhir',
                         'Referrer' => 'http://example.com/fhir' })
        .to_return(status: 200, body: test_condition_response.to_json)

      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$data-requirements"
      ).with(body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},' \
                   '{"name":"periodEnd","valueDate":"2019-12-31"}]}',
             headers: { 'Accept' => 'application/fhir+json',
                        'Content-Type' => 'application/fhir+json' })
        .to_return(status: 200, body: test_library_response.to_json)

      result = run(test, url:, measure_id:, use_fqp_extension: 'true',
                         data_requirements_server_url: url, patient_id:)
      expect(result.result).to eq('pass')
    end

    it 'should fail on invalid query response' do
      stub_request(:get, "#{url}/Condition?code:in=testvs&subject=Patient/#{patient_id}")
        .with(headers: { 'Accept' => 'application/fhir+json',
                         'Content-Type' => 'application/fhir+json',
                         'Origin' => 'http://example.com/fhir',
                         'Referrer' => 'http://example.com/fhir' })
        .to_return(status: 200, body: test_condition_response.to_json)

      stub_request(:get, "#{url}/Condition?code:in=testvs2&subject=Patient/#{patient_id}")
        .with(headers: { 'Accept' => 'application/fhir+json',
                         'Content-Type' => 'application/fhir+json',
                         'Origin' => 'http://example.com/fhir',
                         'Referrer' => 'http://example.com/fhir' })
        .to_return(status: 500, body: error_outcome.to_json)

      stub_request(
        :post,
        "#{url}/Measure/#{measure_id}/$data-requirements"
      ).with(body: '{"resourceType":"Parameters","parameter":[{"name":"periodStart","valueDate":"2019-01-01"},' \
                   '{"name":"periodEnd","valueDate":"2019-12-31"}]}',
             headers: { 'Accept' => 'application/fhir+json',
                        'Content-Type' => 'application/fhir+json' })
        .to_return(status: 200, body: test_library_response.to_json)

      result = run(test, url:, measure_id:, use_fqp_extension: 'true',
                         data_requirements_server_url: url, patient_id:)
      expect(result.result).to eq('fail')
      expect(result.result_message).to eq('Expected response code 200, received: 500 for query: ' \
                                          "/Condition?code%3Ain=testvs2&subject=Patient%2F#{patient_id}")
    end
  end
end
