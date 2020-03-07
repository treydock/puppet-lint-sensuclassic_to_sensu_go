PuppetLint.new_check(:sensuclassic_check) do
  CHECK_PARAMS = {
    'custom'    => 'labels',
    'contacts'  => nil,
    'standalone'  => 'delete',
    'type'      => 'delete',
    'occurrences' => 'delete',
    'refresh' => 'delete',
    'source'  => 'delete',
    'aggregate' => 'delete',
    'aggregates' => 'delete',
    'handle'  => 'delete',
    'dependencies' => 'delete',
    'content' => 'delete',
    'ttl_status' => 'delete',
    'auto_resolve'  => 'delete',
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
    elsif problem[:token].value == 'contacts'
      contacts = ""
      contacts_type = :SSTRING
      contact = false
      contact_start = false
      problem[:tokens].each do |t|
        if t.type == :NAME && t.value == 'contacts'
          contact = true
          next
        end
        if contact && t.type == :LBRACK
          contact_start = true
          next
        end
        if contact && t.type == :RBRACK
          break
        end
        if contact_start
          if t.type == :VARIABLE
            contacts_type = :STRING
            contacts = contacts + "${#{t.value}}"
          end
          if [:DQPRE, :DQMID, :DQPOST, :SSTRING].include?(t.type)
            contacts = contacts + t.value
          end
          if t.type == :COMMA
            contacts = contacts + ', '
          end
        end
      end
      # Remove contacts line
      problem[:tokens].each do |t|
        if t.line == problem[:token].line
          remove_token(t)
        end
      end
      index = 0
      indent = ''
      labels = false
      problem[:tokens].each do |t|
        if t.type == :NAME && ['labels','custom'].include?(t.value)
          labels = true
        end
        if labels && t.type == :RBRACE
          break
        end
        if labels && t.type == :LBRACE
          index = tokens.index(t.next_token)
          indent = t.next_token.next_token.value
        end
      end
      contacts_tokens = [
        PuppetLint::Lexer::Token.new(:NEWLINE, "\n", 0, 0),
        PuppetLint::Lexer::Token.new(:INDENT, indent, 0, 0),
        PuppetLint::Lexer::Token.new(:SSTRING, 'contacts', 0, 0),
        PuppetLint::Lexer::Token.new(:WHITESPACE, ' ', 0, 0),
        PuppetLint::Lexer::Token.new(:FARROW, '=>', 0, 0),
        PuppetLint::Lexer::Token.new(:WHITESPACE, ' ', 0, 0),
      ]
      contacts_tokens << PuppetLint::Lexer::Token.new(contacts_type, contacts, 0, 0)
      contacts_tokens << PuppetLint::Lexer::Token.new(:COMMA, ',', 0, 0)
      contacts_tokens.reverse.each do |t|
        add_token(index, t)
      end
    end
    problem[:token].raw = problem[:token].value unless problem[:token].raw.nil?
  end
end
