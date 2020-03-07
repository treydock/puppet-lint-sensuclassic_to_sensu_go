PuppetLint.new_check(:sensuclassic_check) do
  CHECK_PARAMS = {
    'custom'    => 'labels',
    'contacts'  => nil,
    'standalone'  => 'delete',
    'type'      => 'delete',
  }

  def check
    found_checks = []
    resource_indexes.each do |i|
      if i[:type].type == :NAME && i[:type].value == 'sensuclassic::check'
        found_check = {}
        found_check[:token] = i[:type]
        found_check[:params] = i[:param_tokens]
        found_check[:tokens] = i[:tokens]
        # Handle special case with how 'type' property is seen
        i[:tokens].each do |t|
          if t.type == :TYPE && t.value == 'type'
            found_check[:params] << t
          end
        end
        found_checks << found_check
      end
      #next unless i[:type] == 'sensuclassic::check'
      #puts i
    end

    found_checks.each do |c|
      notify :warning, {
        :message => 'Found sensuclassic::check',
        :line    => c[:token].line,
        :column  => c[:token].column,
        :token   => c[:token],
      }
      c[:params].each do |p|
        if CHECK_PARAMS.key?(p.value)
          notify :warning, {
            :message  => "Found sensuclassic::chek param #{p.value}",
            :line     => p.line,
            :column   => p.column,
            :token    => p,
            :tokens   => c[:tokens],
          }
        end
      end
    end
  end

  def fix(problem)
    if problem[:token].value == 'sensuclassic::check'
      problem[:token].value = 'sensu_check'
    elsif CHECK_PARAMS.key?(problem[:token].value) && CHECK_PARAMS[problem[:token].value].is_a?(String)
      if CHECK_PARAMS[problem[:token].value] == 'delete'
        problem[:tokens].each do |t|
          if t.line == problem[:token].line
            remove_token(t)
          end
        end
      else
        problem[:token].value = CHECK_PARAMS[problem[:token].value]
      end
    elsif CHECK_PARAMS.key?(problem[:token].value) && CHECK_PARAMS[problem[:token].value] == 'contacts'
      resource_indexes.each do |r|
        puts r
      end
    end
    problem[:token].raw = problem[:token].value unless problem[:token].raw.nil?
  end
end
