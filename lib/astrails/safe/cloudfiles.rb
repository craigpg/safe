module Astrails
  module Safe
    class Cloudfiles < Sink
      MAX_CLOUDFILES_FILE_SIZE = 5368709120

      protected

      def active?
        container && user && api_key
      end

      def path
        @path ||= expand(config[:cloudfiles, :path] || config[:local, :path] || ":kind/:id")
      end

      def save
        raise RuntimeError, "pipe-streaming not supported for S3." unless @backup.path

        # needed in cleanup even on dry run
        cf = CloudFiles::Connection.new(:username => user, :api_key => api_key, :retry_auth => true, :snet => service_net) unless $LOCAL
        puts "Uploading #{container}:#{full_path} from #{@backup.path}" if $_VERBOSE || $DRY_RUN
        unless $DRY_RUN || $LOCAL
          if File.stat(@backup.path).size > MAX_CLOUDFILES_FILE_SIZE
            STDERR.puts "ERROR: File size exceeds maximum allowed for upload to Cloud Files (#{MAX_CLOUDFILES_FILE_SIZE}): #{@backup.path}"
            return
          end
          benchmark = Benchmark.realtime do
            cf_container = cf.create_container(container)
            o = cf_container.create_object(full_path,true)
            o.write(File.open(@backup.path))
          end
          puts "...done" if $_VERBOSE
          puts("Upload took " + sprintf("%.2f", benchmark) + " second(s).") if $_VERBOSE
        end
      end

      def cleanup
        return if $LOCAL

        return unless keep = @config[:keep, :cloudfiles]

        puts "listing files: #{container}:#{base}*" if $_VERBOSE
        cf = CloudFiles::Connection.new(:username => user, :api_key => api_key, :retry_auth => true, :snet => service_net) unless $LOCAL
        cf_container = cf.container(container)
        files = cf_container.objects(:prefix => base).sort

        cleanup_with_limit(files, keep) do |f|
          puts "removing Cloud File #{container}:#{f}" if $DRY_RUN || $_VERBOSE
          cf_container.delete_object(f) unless $DRY_RUN || $LOCAL
        end
      end

      def container
        @config[:cloudfiles, :container]
      end

      def user
        @config[:cloudfiles, :user]
      end

      def api_key
        @config[:cloudfiles, :api_key]
      end

      def service_net
        @config[:cloudfiles, :service_net] || false
      end
    end
  end
end
