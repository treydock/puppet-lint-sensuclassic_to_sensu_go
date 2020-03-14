PuppetLint.new_check(:sensuclassic_handler) do
  HANDLER_PARAMS = {
    'pipe'            => nil,
    'filter'          => nil,
    'severities'      => 'delete',
    'handle_silenced' => 'delete',
    'handle_flapping' => 'delete',
  }

  def check
    resource_indexes.each do |i|
      if i[:type].type != :NAME || !['sensuclassic_handler', 'sensuclassic::handler'].include?(i[:type].value)
        next
      end
      notify :warning, {
        :message => "Found #{i[:type].value}",
        :line    => i[:type].line,
        :column  => i[:type].column,
        :token   => i[:type],
        :tokens  => i[:tokens],
      }
      i[:param_tokens].each do |t|
        if HANDLER_PARAMS.key?(t.value)
          notify :warning, {
            :message  => "Found #{i[:type].value} param #{t.value}",
            :line     => t.line,
            :column   => t.column,
            :token    => t,
            :tokens   => i[:tokens],
          }
        end
      end
      params = []
      param = nil
      skip_ensure = false
      i[:tokens].each do |t|
        if t.type == :NAME
          params << t.value
          param = t.value
        end
        # Handle special case with how 'type' property is seen
        if t.type == :TYPE && t.value == 'type'
          params << t.value
          param = t.value
        end
        if param == 'type' && [:STRING,:SSTRING].include?(t.type) && ['amqp','transport'].include?(t.value)
          if t.value == 'amqp'
            skip_ensure = true
            _tokens = [i[:type]] + i[:tokens]
          else
            _tokens = i[:tokens]
          end
          notify :warning, {
            :message  => "Found type param #{t.value}",
            :line     => t.line,
            :column   => t.column,
            :token    => t,
            :tokens   => _tokens,
          }
        end
        if ['filters','filter'].include?(param) && [:STRING,:SSTRING].include?(t.type) && ['check_dependencies','occurrences'].include?(t.value)
          notify :warning, {
            :message  => "Found filter value #{t.value}",
            :line     => t.line,
            :column   => t.column,
            :token    => t,
            :tokens   => i[:tokens],
          }
        end
      end
      if !params.include?('ensure') && !skip_ensure
        notify :warning, {
          :message  => "Missing 'ensure' parameter for #{i[:type].value}",
          :line     => i[:type].line,
          :column   => i[:type].column,
          :token   => i[:type],
          :tokens  => i[:tokens],
        }
      end
    end
  end

  def fix(problem)
    # CASE: Replace resource type
    if ['sensuclassic::handler', 'sensuclassic_handler'].include?(problem[:token].value)
      problem[:token].value = 'sensu_handler'
    # CASE: Add ensure parameter
    elsif problem[:message] =~ /'ensure' parameter/
      indent = nil
      index = nil
      problem[:tokens].each do |t|
        if t.type == :INDENT
          indent = t.value
          index = tokens.index(t)
          break
        end
      end
      ensure_tokens = [
        PuppetLint::Lexer::Token.new(:INDENT, indent, 0, 0),
        PuppetLint::Lexer::Token.new(:NAME, 'ensure', 0, 0),
        PuppetLint::Lexer::Token.new(:WHITESPACE, ' ', 0, 0),
        PuppetLint::Lexer::Token.new(:FARROW, '=>', 0, 0),
        PuppetLint::Lexer::Token.new(:WHITESPACE, ' ', 0, 0),
        PuppetLint::Lexer::Token.new(:SSTRING, 'present', 0, 0),
        PuppetLint::Lexer::Token.new(:COMMA, ',', 0, 0),
        PuppetLint::Lexer::Token.new(:NEWLINE, "\n", 0, 0),
      ]
      ensure_tokens.reverse.each do |t|
        add_token(index, t)
      end
    # CASE: Remove type=amqp
    elsif problem[:token].value == 'amqp'
      removelines = []
      first = problem[:tokens].first
      last = problem[:tokens].last
      if first.prev_token.prev_token.type == :NEWLINE
        remove_token(first.prev_token.prev_token)
      end
      problem[:tokens].each do |t|
        if !removelines.include?(t.line)
          removelines << t.line
        end
      end
      tokens.reverse.each do |t|
        if removelines.include?(t.line)
          remove_token(t)
        end
      end
    # CASE: Handle client_attributes Hash to become entity_attributes Array
    elsif problem[:token].value == 'occ'
      problem[:token].value = 'entity_attributes'
      token = problem[:token]
      client_attributes = false
      entity_attributes = []
      removeline = nil
      startremove = nil
      endremove = nil
      index = nil
      while true
        token = token.next_token
        if token.type == :LBRACE
          client_attributes = true
          token.type = :LBRACK
          token.value = '['
          next
        end
        if token.type == :RBRACE
          token.type = :RBRACK
          token.value = ']'
          break
        end
        if client_attributes && [:STRING,:SSTRING].include?(token.type)
          if token.next_token.next_token.type == :FARROW
            key = token.value
            removeline = token.line
            startremove = token.column
            index = tokens.index(token)
          else
            attr = "entity.labels.#{key} == '#{token.value}'"
            entity_attributes << attr
            endremove = token.column
          end
        end
      end
      # Remove previous values
      problem[:tokens].each do |t|
        if t.line == removeline && t.column >= startremove
          remove_token(t)
        end
        if t.line >= removeline && t.column > endremove
          break
        end
      end
      entity_attributes.each do |e|
        add_token(index, PuppetLint::Lexer::Token.new(:COMMA, ',', 0, 0))
        add_token(index, PuppetLint::Lexer::Token.new(:STRING, e, 0, 0))
      end
    # CASE: Regular parameter replacements or deletes
    elsif HANDLER_PARAMS.key?(problem[:token].value) && HANDLER_PARAMS[problem[:token].value].is_a?(String)
      param = problem[:token].value
      newparam = HANDLER_PARAMS[param]
      if newparam == 'delete'
        problem[:tokens].each do |t|
          if t.line == problem[:token].line
            remove_token(t)
          end
        end
      else
        problem[:token].value = newparam
        if param.size > newparam.size
          spaces = problem[:token].next_token.value.size
          newspace = ' ' * (spaces + (param.size - newparam.size))
          problem[:token].next_token.value = newspace
        elsif newparam.size > param.size
          spaces = problem[:token].next_token.value.size
          newspaces = spaces - (newparam.size - param.size)
          if newspaces > 0
            newspace = ' ' * newspaces
            problem[:token].next_token.value = newspace
          end
        end
      end
    # CASE: Handle contacts to contacts label
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
      contacts_tokens = [
        PuppetLint::Lexer::Token.new(:SSTRING, 'contacts', 0, 0),
        PuppetLint::Lexer::Token.new(:WHITESPACE, ' ', 0, 0),
        PuppetLint::Lexer::Token.new(:FARROW, '=>', 0, 0),
        PuppetLint::Lexer::Token.new(:WHITESPACE, ' ', 0, 0),
        PuppetLint::Lexer::Token.new(contacts_type, contacts, 0, 0),
        PuppetLint::Lexer::Token.new(:COMMA, ',', 0, 0),
      ]
      add_to_labels(problem, contacts_tokens)
    # CASE: Handle occurrences to fatigue_check
    elsif problem[:token].value == 'occurrences'
      problem[:token].value = 'fatigue_check'
    elsif problem[:token].value == 'check_dependencies'
      if problem[:token].next_token.type == :COMMA
        if problem[:token].next_token.next_token.type == :WHITESPACE
          remove_token(problem[:token].next_token.next_token)
        end
        remove_token(problem[:token].next_token)
      elsif problem[:token].next_token.type == :RBRACK
        if problem[:token].prev_token.type == :WHITESPACE
          if problem[:token].prev_token.prev_token.type == :COMMA
            remove_token(problem[:token].prev_token.prev_token)
          end
          remove_token(problem[:token].prev_token)
        end
      end
      remove_token(problem[:token])
    # CASE: Handler filter
    elsif problem[:token].value == 'filter'
      params = []
      problem[:tokens].each do |t|
        if t.type == :NAME || (t.type == :TYPE && t.value == 'type')
          params << t.value
        end
      end
      filter = false
      value = nil
      type = nil
      removeline = nil
      problem[:tokens].each do |t|
        if t.type == :NAME && t.value == 'filter'
          filter = true
          removeline = t.line
          next
        end
        if filter && [:STRING,:SSTRING,:VARIABLE].include?(t.type)
          value = t.value
          type = t.type
          break
        end
      end
      if value == 'occurrences'
        value = 'fatigue_check'
      end
      if params.include?('filters')
        filters = false
        index = nil
        problem[:tokens].each do |t|
          if t.type == :NAME && t.value == 'filters'
            filters = true
            next
          end
          if filters && t.type == :RBRACK
            index = tokens.index(t)
            break
          end
        end
        add_token(index, PuppetLint::Lexer::Token.new(type, value, 0, 0))
        add_token(index, PuppetLint::Lexer::Token.new(:WHITESPACE, ' ', 0, 0))
        add_token(index, PuppetLint::Lexer::Token.new(:COMMA, ',', 0, 0))
      else
        new_value = PuppetLint::Lexer::Token.new(type, value, 0, 0)
        add_filters(problem, new_value)
      end
      problem[:tokens].each do |t|
        if t.line == removeline
          remove_token(t)
        end
      end
    end
  end

  def add_filters(problem, value)
    indent = problem[:tokens].last.prev_token.value + '  '
    index = tokens.index(problem[:tokens].last.prev_token)
    filters_tokens = [
      PuppetLint::Lexer::Token.new(:INDENT, indent, 0, 0),
      PuppetLint::Lexer::Token.new(:NAME, 'filters', 0, 0),
      PuppetLint::Lexer::Token.new(:WHITESPACE, ' ', 0, 0),
      PuppetLint::Lexer::Token.new(:FARROW, '=>', 0, 0),
      PuppetLint::Lexer::Token.new(:WHITESPACE, ' ', 0, 0),
      PuppetLint::Lexer::Token.new(:LBRACK, '[', 0, 0),
    ]
    filters_tokens << value
    filters_tokens << PuppetLint::Lexer::Token.new(:RBRACK, ']', 0, 0)
    filters_tokens << PuppetLint::Lexer::Token.new(:COMMA, ',', 0, 0)
    filters_tokens << PuppetLint::Lexer::Token.new(:NEWLINE, "\n", 0, 0)
    filters_tokens.reverse.each do |t|
      add_token(index, t)
    end
  end
end
