# typed: true # rubocop:todo Sorbet/StrictSigil
# frozen_string_literal: true

require "cask/artifact/symlinked"

module Cask
  module Artifact
    # Artifact corresponding to the `shim_script` stanza.
    class ShimScript < Binary
      sig {
        params(
          cask:    Cask,
          source:  T.nilable(T.any(String, Pathname)),
          target:  T.nilable(T.any(String, Pathname)),
          wrapper: T.nilable(String),
          args:    T.any(String, Pathname, T::Array[T.any(String, Pathname)]),
          shell:   String,
        ).void
      }
      def initialize(cask, source, target: nil, wrapper: nil, args: "$@", shell: "/bin/bash")
        raise CaskInvalidError, "`wrapper` must be a file name not a path" if wrapper&.include?("/")

        @command = source.to_s
        @wrapper = cask.staged_path.join(wrapper || "#{File.basename(@command)}.wrapper.sh").to_s
        @args = Array(args)
        @shell = shell

        target_hash = {}
        target_hash[:target] = target unless target.nil?
        super(cask, @wrapper, **target_hash)
      end

      def install_phase(**options)
        File.write @wrapper, <<~EOS
          #!#{@shell}
          exec "#{@command}" #{@args.map { |arg| "\"#{arg}\"" }.join(" ")}
        EOS
        super
      end
    end
  end
end
