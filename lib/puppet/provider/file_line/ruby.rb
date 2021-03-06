Puppet::Type.type(:file_line).provide(:ruby) do
  def exists?
    lines.find do |line|
      line.chomp == resource[:line].chomp
    end
  end

  def create
    if resource[:match]
      handle_create_with_match
    elsif resource[:after]
      handle_create_with_after
    else
      append_line
    end
  end

  def destroy
    local_lines = lines
    File.open(resource[:path],'w') do |fh|
      fh.write(local_lines.reject{|l| l.chomp == resource[:line] }.join(''))
    end
  end

  private
  def lines
    # If this type is ever used with very large files, we should
    #  write this in a different way, using a temp
    #  file; for now assuming that this type is only used on
    #  small-ish config files that can fit into memory without
    #  too much trouble.
    @lines ||= File.readlines(resource[:path])
  end

  def handle_create_with_match()
    regex        = resource[:match] ? Regexp.new(resource[:match]) : nil
    regex_after  = resource[:after] ? Regexp.new(resource[:after]) : nil
    regex_unless = resource[:unless] ? Regexp.new(resource[:unless]) : nil
    match_count  = count_matches(regex)

    if match_count > 1 && resource[:multiple].to_s != 'true'
     raise Puppet::Error, "More than one line in file '#{resource[:path]}' matches pattern '#{resource[:match]}'"
    end

    File.open(resource[:path], 'w') do |fh|
      lines.each do |l|
        if regex.match(l)
            if regex_unless
                unless regex_unless.match(l)
                    fh.puts(l.sub(regex, resource[:line]))
                else
                    fh.puts(l)
                end
            else
                fh.puts(l.sub(regex, resource[:line]))
            end
        else
            fh.puts(l)
        end
        if (match_count == 0 and regex_after)
          if regex_after.match(l)
            fh.puts(resource[:line])
            match_count += 1 #Increment match_count to indicate that the new line has been inserted.
          end
        end
      end

      if (match_count == 0)
        if resource[:no_append].to_s != 'true'
          fh.puts(resource[:line])
        end
      end
    end
  end

  def handle_create_with_after
    regex = Regexp.new(resource[:after])
    count = count_matches(regex)

    if count > 1 && resource[:multiple].to_s != 'true'
      raise Puppet::Error, "#{count} lines match pattern '#{resource[:after]}' in file '#{resource[:path]}'.  One or no line must match the pattern."
    end

    File.open(resource[:path], 'w') do |fh|
      lines.each do |l|
        fh.puts(l)
        if regex.match(l) then
          fh.puts(resource[:line])
        end
      end
    end

    if (count == 0) # append the line to the end of the file
      append_line
    end
  end

  def count_matches(regex)
    lines.select{|l| l.match(regex)}.size
  end

  ##
  # append the line to the file.
  #
  # @api private
  def append_line
    File.open(resource[:path], 'w') do |fh|
      lines.each do |l|
        fh.puts(l)
      end
      fh.puts resource[:line]
    end
  end
end
