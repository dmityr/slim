module Slim
  # Compiles Slim expressions into Temple::HTML expressions.
  class Compiler < Filter
    def on_text(string)
      # Interpolate variables in text (#{variable}).
      # Split the text into multiple dynamic and static parts.
      block = [:multi]
      until string.empty?
        case string
        when /^\\(\#\{[^\}]*\})/
          # Escaped interpolation
          block << [:static, $1]
        when /^\#\{([^\}]*)\}/
          # Interpolation
          block << [:dynamic, escape_code($1)]
        when /^([^\#]+|\#)/
          # Static text
          block << [:static, $&]
        end
        string = $'
      end
      block
    end

    def on_control(code, content)
      [:multi,
        [:block, code],
        compile(content)]
    end

    def on_output(escape, code, content)
      if empty_exp?(content)
        [:multi, [:dynamic, escape ? escape_code(code) : code], content]
      else
        on_output_block(escape, code, content)
      end
    end

    def on_output_block(escape, code, content)
      tmp1, tmp2 = tmp_var, tmp_var

      [:multi,
        # Capture the result of the code in a variable. We can't do
        # `[:dynamic, code]` because it's probably not a complete
        # expression (which is a requirement for Temple).
        [:block, "#{tmp1} = #{code}"],

        # Capture the content of a block in a separate buffer. This means
        # that `yield` will not output the content to the current buffer,
        # but rather return the output.
        [:capture, tmp2,
         compile(content)],

        # Make sure that `yield` returns the output.
        [:block, tmp2],

        # Close the block.
        [:block, 'end'],

        # Output the content.
        on_output(escape, tmp1, [:multi])]
    end

    def on_directive(type)
      if type =~ /^doctype/
        [:html, :doctype, $'.strip]
      end
    end

    def on_tag(name, attrs, content)
      attrs = attrs.inject([:html, :attrs]) do |m, (key, dynamic, value)|
        value = if dynamic
                  [:dynamic, escape_code(value)]
                else
                  on_text(value)
                end
        m << [:html, :basicattr, [:static, key.to_s], value]
      end

      [:html, :tag, name, attrs, compile(content)]
    end

    private

    def escape_code(param)
      "Slim::Helpers.escape_html#{@options[:use_html_safe] ? '_safe' : ''}((#{param}))"
    end

    def tmp_var
      @tmp_var ||= 0
      "_slimtmp#{@tmp_var += 1}"
    end
  end
end
