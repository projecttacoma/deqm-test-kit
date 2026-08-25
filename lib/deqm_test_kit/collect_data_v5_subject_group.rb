# frozen_string_literal: true

require 'json'
require_relative '../utils/collect_data_utils'

module DEQMTestKit
  # tests for $collect-data subjectGroup (DEQM v5.0.0)
  class CollectDataV5SubjectGroup < Inferno::TestGroup
    id :collect_data_v5_subjectGroup
    title '$collect-data with subjectGroup'
    description 'Ensure FHIR server can perform the $collect-data operation with subjectGroup'

    fhir_client do
      url :url
      headers origin: url.to_s,
              referrer: url.to_s,
              'Content-Type': 'application/fhir+json'
    end

    measure_options = JSON.parse(File.read('./lib/fixtures/measureRadioButton.json'))
    additional_measure_options = JSON.parse(File.read('./lib/fixtures/measureCheckBoxes.json'))
    measure_id_args = {
      type: 'radio',
      optional: false,
      default: 'CMS0334FHIRPCCesareanBirth',
      options: measure_options,
      title: 'Measure Title'
    }
    additional_measures_args = {
      type: 'checkbox',
      optional: true,
      options: additional_measure_options,
      title: 'Additional Measure Ids',
      default: ['']
    }
    custom_measure_id_args = {
      type: 'text',
      optional: true,
      title: 'Custom Measure ID',
      description: 'If you selected "Other" above or want to provide a custom Measure ID, enter it here.'
    }
    test do # rubocop:disable Metrics/BlockLength
      include CollectDataUtils

      title 'POST Measure/$collect-data with one measureId, periodStart, periodEnd, and subjectGroup'
      id 'collect-data-one-measure-post-subject-group'
      description %(POST Measure/$collect-data with one measureId, periodStart, periodEnd, and
      subjectGroup returns 200 and FHIR Parameters resource that contains X (patient count)
      number of FHIR Bundles that each contain one MeasureReport)

      input :measure_id, **measure_id_args
      input :custom_measure_id, **custom_measure_id_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'
      input :patient_ids,
            title: 'Patient IDs',
            description: 'Enter a comma-delimited list of patient IDs.'

      run do
        patient_id_list = patient_ids.split(',').map(&:strip).reject(&:empty?)

        body = collect_data_body(
          measure_ids: [selected_measure_id(custom_id: custom_measure_id, id: measure_id)],
          period_start: period_start,
          period_end: period_end,
          patient_id_list: patient_id_list
        )

        result = fhir_operation('/Measure/$collect-data', body: body)

        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource

        validate_parameters_contains_bundles(parameters, 1)
        validate_number_of_bundles(parameters, patient_id_list.length)
      end
    end

    test do # rubocop:disable Metrics/BlockLength
      include CollectDataUtils

      title 'POST Measure/$collect-data with two measureIds, periodStart, periodEnd, and subjectGroup'
      id 'collect-data-two-measures-post-subject-group'
      description %(POST Measure/$collect-data with two measureIds, periodStart, periodEnd, and
      subjectGroup returns 200 and FHIR Parameters resource that contains X (patient count)
      number of FHIR Bundles that each contain two MeasureReports)

      input :measure_id, **measure_id_args
      input :custom_measure_id, **custom_measure_id_args
      input :additional_measures, **additional_measures_args
      input :period_start, title: 'Measurement Period Start', default: '2026-01-01'
      input :period_end, title: 'Measurement Period End', default: '2026-12-31'
      input :patient_ids,
            title: 'Patient IDs',
            description: 'Enter a comma-delimited list of patient IDs.'

      run do
        patient_id_list = patient_ids.split(',').map(&:strip).reject(&:empty?)

        measure_ids = [selected_measure_id(custom_id: custom_measure_id, id: measure_id)]
        measure_ids += additional_measures if additional_measures&.any?

        body = collect_data_body(
          measure_ids: measure_ids,
          period_start: period_start,
          period_end: period_end,
          patient_id_list: patient_id_list
        )

        result = fhir_operation('/Measure/$collect-data', body: body)

        assert_response_status(200)
        assert result.resource.is_a?(FHIR::Parameters), "Expected
        resource to be a Parameters resource, but got #{result.resource&.class}"

        parameters = result.resource

        validate_parameters_contains_bundles(parameters, measure_ids.length)
        validate_number_of_bundles(parameters, patient_id_list.length)
      end
    end
  end
end
