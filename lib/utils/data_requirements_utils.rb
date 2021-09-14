# frozen_string_literal: true

module DEQMTestKit
  module DataRequirementsUtils
    def get_filter_str(code_filter)
      ret_val = '(no code filter)'

      if code_filter&.code&.first
        code = code_filter.first.code.first
        ret_val = "(#{code.system}|#{code.code})"
      elsif code_filter&.valueSet
        ret_val = "(#{code_filter.valueSet})"
      end

      ret_val
    end

    def get_dr_comparison_list(data_requirement)
      data_requirement.map do |dr|
        dr_resource = FHIR::DataRequirement.new dr
        cf = dr_resource.codeFilter&.first
        filter_str = get_filter_str cf

        path = cf&.path ? ".#{cf.path}" : ''

        "#{dr_resource.type}#{path}#{filter_str}"
      end
    end
  end
end
