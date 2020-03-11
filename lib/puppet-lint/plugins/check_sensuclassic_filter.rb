PuppetLint.new_check(:sensuclassic_filter) do
  def check
    resource_indexes.each do |i|
      if i[:type].type != :NAME || !['sensuclassic_filter', 'sensuclassic::filter'].include?(i[:type].value)
        next
      end
      notify :warning, {
        :message => "Found #{i[:type].value}",
        :line    => i[:type].line,
        :column  => i[:type].column,
        :token   => i[:type],
        :tokens  => i[:tokens],
      }
    end
  end
end
