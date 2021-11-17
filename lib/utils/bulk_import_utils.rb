# frozen_string_literal: true
# Utility functions in support of the bulk import test group
module DEQMTestKit
 module BulkImportUtils
      def get_retry_or_backoff_time(wait_time, reply)
        retry_after = -1
        unless reply.headers.nil?
           reply.headers.symbolize_keys
           retry_after = reply.headers[:retry_after].to_i || -1
         end
         if retry_after.positive?
           retry_after
         else
           wait_time * 2
         end
      end
  end
end
