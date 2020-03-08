PuppetLint.new_check(:sensuclassic_check) do
  CHECK_PARAMS = {
    'custom'    => 'labels',
    'subscribers' => 'subscriptions',
    'contacts'  => nil,
    'occurrences' => nil,
    'standalone'  => 'delete',
    'type'      => 'delete',
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
    resource_indexes.each do |i|
      if i[:type].type != :NAME && i[:type].value != 'sensuclassic::check'
        next
      end
      notify :warning, {
        :message => 'Found sensuclassic::check',
        :line    => i[:type].line,
        :column  => i[:type].column,
        :token   => i[:type],
      }
      i[:param_tokens].each do |t|
        if CHECK_PARAMS.key?(t.value)
          notify :warning, {
            :message  => "Found sensuclassic::chek param #{t.value}",
            :line     => t.line,
            :column   => t.column,
            :token    => t,
            :tokens   => i[:tokens],
          }
        end
      end
      i[:tokens].each do |t|
        # Handle special case with how 'type' property is seen
        if t.type == :TYPE && t.value == 'type'
          notify :warning, {
            :message  => "Found sensuclassic::chek param #{t.value}",
            :line     => t.line,
            :column   => t.column,
            :token    => t,
            :tokens   => i[:tokens],
          }
        end
        if [:STRING,:SSTRING].include?(t.type)
          if t.value =~ /:::/
            notify :warning, {
              :message  => "Found sensuclassic token substitution",
              :line     => t.line,
              :column   => t.column,
              :token    => t,
              :tokens   => i[:tokens],
            }
          end
          if t.value == 'client_attributes'
            notify :warning, {
              :message  => "Found sensuclassic hash key '#{t.value}'",
              :line     => t.line,
              :column   => t.column,
              :token    => t,
              :tokens   => i[:tokens],
            }
          end
        end
      end
    end
  end

  def fix(problem)
    # Replace resource type
    if problem[:token].value == 'sensuclassic::check'
      problem[:token].value = 'sensu_check'
    # Replace ::: token substitition with {{ or }} Senso Go token substitution
    elsif problem[:message] =~ /token substitution/
      values = []
      problem[:token].value.split(/(?=:::)/).each_with_index do |v,i|
        if i.odd?
          newv = v.gsub(":::", "{{")
        else
          newv = v.gsub(":::", "}}")
        end
        if newv =~ /(\{\{)|(\}\})/
          newv = newv.split(/( )?\|( )?/).join(' | default ')
        end
        values << newv
      end
      problem[:token].value = values.join
    # Handle client_attributes Hash to become entity_attributes Array
    elsif problem[:token].value == 'client_attributes'
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
    # Regular parameter replacements or deletes
    elsif CHECK_PARAMS.key?(problem[:token].value) && CHECK_PARAMS[problem[:token].value].is_a?(String)
      param = problem[:token].value
      newparam = CHECK_PARAMS[param]
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
    elsif problem[:token].value == 'occurrences'
      occurrences = false
      occurrences_value = nil
      problem[:tokens].each do |t|
        if t.type == :NAME && t.value == 'occurrences'
          occurrences = true
        end
        if occurrences && t.type == :NUMBER
          occurrences_value = t.value
          break
        end
      end
      # Remove occurrences line
      problem[:tokens].each do |t|
        if t.line == problem[:token].line
          remove_token(t)
        end
      end
      occurrences_tokens = [
        PuppetLint::Lexer::Token.new(:SSTRING, 'fatigue_check/occurrences', 0, 0),
        PuppetLint::Lexer::Token.new(:WHITESPACE, ' ', 0, 0),
        PuppetLint::Lexer::Token.new(:FARROW, '=>', 0, 0),
        PuppetLint::Lexer::Token.new(:WHITESPACE, ' ', 0, 0),
        PuppetLint::Lexer::Token.new(:NUMBER, occurrences_value, 0, 0),
        PuppetLint::Lexer::Token.new(:COMMA, ',', 0, 0),
      ]
      add_to_annotations(problem, occurrences_tokens)
    end
    problem[:token].raw = problem[:token].value unless problem[:token].raw.nil?
  end

  def add_to_labels(problem, param_tokens)
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
    if !labels
      indent = problem[:tokens].last.prev_token.value + '  '
      index = tokens.index(problem[:tokens].last.prev_token)
      labels_tokens = [
        PuppetLint::Lexer::Token.new(:INDENT, indent, 0, 0),
        PuppetLint::Lexer::Token.new(:NAME, 'labels', 0, 0),
        PuppetLint::Lexer::Token.new(:WHITESPACE, ' ', 0, 0),
        PuppetLint::Lexer::Token.new(:FARROW, '=>', 0, 0),
        PuppetLint::Lexer::Token.new(:WHITESPACE, ' ', 0, 0),
        PuppetLint::Lexer::Token.new(:LBRACE, '{', 0, 0),
        PuppetLint::Lexer::Token.new(:NEWLINE, "\n", 0, 0),
        PuppetLint::Lexer::Token.new(:INDENT, indent + '  ', 0, 0),
      ]
    else
      labels_tokens = [
        PuppetLint::Lexer::Token.new(:NEWLINE, "\n", 0, 0),
        PuppetLint::Lexer::Token.new(:INDENT, indent, 0, 0),
      ]
    end
    param_tokens.each do |t|
      labels_tokens << t
    end
    if !labels
      labels_tokens << PuppetLint::Lexer::Token.new(:NEWLINE, "\n", 0, 0)
      labels_tokens << PuppetLint::Lexer::Token.new(:INDENT, indent, 0, 0)
      labels_tokens << PuppetLint::Lexer::Token.new(:RBRACE, '}', 0, 0)
      labels_tokens << PuppetLint::Lexer::Token.new(:COMMA, ',', 0, 0)
      labels_tokens << PuppetLint::Lexer::Token.new(:NEWLINE, "\n", 0, 0)
    end
    labels_tokens.reverse.each do |t|
      add_token(index, t)
    end
  end

  def add_to_annotations(problem, param_tokens)
    index = 0
    indent = ''
    annotations = false
    problem[:tokens].each do |t|
      if t.type == :NAME && t.value == 'annotations'
        annotations = true
      end
      if annotations && t.type == :RBRACE
        break
      end
      if annotations && t.type == :LBRACE
        index = tokens.index(t.next_token)
        indent = t.next_token.next_token.value
      end
    end
    if !annotations
      indent = problem[:tokens].last.prev_token.value + '  '
      index = tokens.index(problem[:tokens].last.prev_token)
      annotations_tokens = [
        PuppetLint::Lexer::Token.new(:INDENT, indent, 0, 0),
        PuppetLint::Lexer::Token.new(:NAME, 'annotations', 0, 0),
        PuppetLint::Lexer::Token.new(:WHITESPACE, ' ', 0, 0),
        PuppetLint::Lexer::Token.new(:FARROW, '=>', 0, 0),
        PuppetLint::Lexer::Token.new(:WHITESPACE, ' ', 0, 0),
        PuppetLint::Lexer::Token.new(:LBRACE, '{', 0, 0),
        PuppetLint::Lexer::Token.new(:NEWLINE, "\n", 0, 0),
        PuppetLint::Lexer::Token.new(:INDENT, indent + '  ', 0, 0),
      ]
    else
      annotations_tokens = [
        PuppetLint::Lexer::Token.new(:NEWLINE, "\n", 0, 0),
        PuppetLint::Lexer::Token.new(:INDENT, indent, 0, 0),
      ]
    end
    param_tokens.each do |t|
      annotations_tokens << t
    end
    annotations_tokens << PuppetLint::Lexer::Token.new(:NEWLINE, "\n", 0, 0)
    annotations_tokens << PuppetLint::Lexer::Token.new(:INDENT, indent, 0, 0)
    annotations_tokens << PuppetLint::Lexer::Token.new(:RBRACE, '}', 0, 0)
    annotations_tokens << PuppetLint::Lexer::Token.new(:COMMA, ',', 0, 0)
    annotations_tokens << PuppetLint::Lexer::Token.new(:NEWLINE, "\n", 0, 0)
    annotations_tokens.reverse.each do |t|
      add_token(index, t)
    end
  end
end
