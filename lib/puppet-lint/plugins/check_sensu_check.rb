PuppetLint.new_check(:sensu_check) do
  def check
    resource_indexes.each do |i|
      if i[:type].type != :NAME || !['sensu_check'].include?(i[:type].value)
        next
      end
      param = nil
      i[:tokens].each do |t|
        if t.type == :NAME
          param = t.value
        end
        if ['labels','annotations'].include?(param) && [:TRUE,:FALSE,:NUMBER].include?(t.type)
          notify :warning, {
            :message  => "Found #{param} value #{t.value}",
            :line     => t.line,
            :column   => t.column,
            :token    => t,
          }
        end
      end
    end
  end

  def fix(problem)
    problem[:token].type = :SSTRING
  end
end
