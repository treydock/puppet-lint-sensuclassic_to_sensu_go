PuppetLint.new_check(:sensuclassic_check) do
  CHECK_PARAMS = {
    'custom'    => 'labels',
    'subscribers' => 'subscriptions',
    'source'  => 'proxy_entity_name',
    'hooks' => nil,
    'contacts'  => nil,
    'occurrences' => nil,
    'standalone'  => 'delete',
    'type'      => 'delete',
    'refresh' => 'delete',
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
      if i[:type].type != :NAME || !['sensuclassic_check', 'sensuclassic::check'].include?(i[:type].value)
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
        if CHECK_PARAMS.key?(t.value)
          notify :warning, {
            :message  => "Found #{i[:type].value} param #{t.value}",
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
            :message  => "Found #{i[:type]} param #{t.value}",
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
          if t.type == :NAME && t.value == 'hooks'
            notify :warning, {
              :message => "Found #{i[:type].value} with hooks defined",
              :line    => t.line,
              :column  => t.column,
              :token   => t,
              :tokens  => i[:tokens],
            }
          end
        end
      end
    end
  end

  def fix(problem)
    # CASE: Replace resource type
    if ['sensuclassic::check', 'sensuclassic_check'].include?(problem[:token].value)
      problem[:token].value = 'sensu_check'
    # CASE: Replace ::: token substitition with {{ or }} Senso Go token substitution
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
    # CASE: Handle client_attributes Hash to become entity_attributes Array
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
    # CASE: Regular parameter replacements or deletes
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
    # CASE: Handle occurrences to annotation
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
    # CASE: Handle hooks reformat
    elsif ['hooks', 'check_hooks'].include?(problem[:token].value)
      problem[:token].value = 'check_hooks'
      check_name = problem[:tokens][0].prev_token.value
      found_hooks = {}
      hooks = false
      hookname = nil
      brackets = nil
      delete = false
      problem[:tokens].each do |t|
        if t.type == :NAME && t.value == 'check_hooks'
          hooks = true
        end
        if hooks && t.type == :LBRACE
          if brackets.nil?
            brackets = 1
          else
            brackets += 1
          end
          t.type = :LBRACK
          t.value = '['
          if brackets > 1
            index = tokens.index(t.next_token)
            #add_token(index, PuppetLint::Lexer::Token.new(:COMMA, ',', 0, 0))
            #add_token(index, PuppetLint::Lexer::Token.new(:RBRACE, '}', 0, 0))
            add_token(index, PuppetLint::Lexer::Token.new(:WHITESPACE, ' ', 0, 0))
            add_token(index, PuppetLint::Lexer::Token.new(:RBRACK, ']', 0, 0))
            add_token(index, PuppetLint::Lexer::Token.new(:SSTRING, hookname, 0, 0))
          end
          if brackets.even?
            delete = true
          end
          next
        end
        if hooks && t.type == :RBRACE
          brackets -= 1
          hookname = nil
          if brackets == 0
            t.type = :RBRACK
            t.value = ']'
            break
          end
          delete = false
          next
        end
        if hooks && brackets && [:STRING,:SSTRING].include?(t.type) && hookname.nil?
          hookname = "#{t.value}-#{check_name}"
          found_hooks[hookname] = {}
          index = tokens.index(t)
          add_token(index, PuppetLint::Lexer::Token.new(:WHITESPACE, ' ', 0, 0))
          add_token(index, PuppetLint::Lexer::Token.new(:LBRACE, '{', 0, 0))
          next
        end
        if hookname && [:STRING,:SSTRING, :NUMBER, :TRUE, :FALSE].include?(t.type)
          if t.next_token.next_token.type == :FARROW
            key = t.value
          else
            found_hooks[hookname][key] = t
          end
        end
        if hookname && delete
          remove_token(t)
        end
      end
      found_hooks.reverse_each do |name, params|
        add_hook(problem, name, params)
      end
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
      last = problem[:tokens].last
      while ! last.nil?
        last = last.prev_token
        if last.type == :NEWLINE
          if last.prev_token.type != :COMMA
            add_token(tokens.index(last), PuppetLint::Lexer::Token.new(:COMMA, ',', 0, 0))
          end
          break
        end
      end
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

  def add_hook(problem, name, params)
    index = tokens.index(problem[:tokens].last.next_token)
    indent = problem[:tokens].last.prev_token.value
    hook_tokens = [
      PuppetLint::Lexer::Token.new(:NEWLINE, "\n", 0, 0),
      PuppetLint::Lexer::Token.new(:NEWLINE, "\n", 0, 0),
      PuppetLint::Lexer::Token.new(:INDENT, indent, 0, 0),
      PuppetLint::Lexer::Token.new(:NAME, 'sensu_hook', 0, 0),
      PuppetLint::Lexer::Token.new(:WHITESPACE, ' ', 0, 0),
      PuppetLint::Lexer::Token.new(:LBRACE, '{', 0, 0),
      PuppetLint::Lexer::Token.new(:WHITESPACE, ' ', 0, 0),
      PuppetLint::Lexer::Token.new(:SSTRING, name, 0, 0),
      PuppetLint::Lexer::Token.new(:COLON, ':', 0, 0),
      PuppetLint::Lexer::Token.new(:NEWLINE, "\n", 0, 0),
    ]
    params = {'ensure' => PuppetLint::Lexer::Token.new(:SSTRING, 'present', 0, 0)}.merge(params)
    maxparam = params.max_by { |k,v| k }[0]
    params.each_pair do |k,v|
      whitespace = (maxparam.size - k.size) + 1
      if whitespace < 1
        whitespace = 1
      end
      hook_tokens << PuppetLint::Lexer::Token.new(:INDENT, indent + '  ', 0, 0)
      hook_tokens << PuppetLint::Lexer::Token.new(:NAME, k, 0, 0)
      hook_tokens << PuppetLint::Lexer::Token.new(:WHITESPACE, ' ' * whitespace, 0, 0)
      hook_tokens << PuppetLint::Lexer::Token.new(:FARROW, '=>', 0, 0)
      hook_tokens << PuppetLint::Lexer::Token.new(:WHITESPACE, ' ', 0, 0)
      hook_tokens << v
      hook_tokens << PuppetLint::Lexer::Token.new(:COMMA, ',', 0, 0)
      hook_tokens << PuppetLint::Lexer::Token.new(:NEWLINE, "\n", 0, 0)
    end
    hook_tokens << PuppetLint::Lexer::Token.new(:INDENT, indent, 0, 0)
    hook_tokens << PuppetLint::Lexer::Token.new(:RBRACE, '}', 0, 0)
    hook_tokens.reverse.each do |t|
      add_token(index, t)
    end
  end
end
