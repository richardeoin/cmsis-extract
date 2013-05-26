# Extracts CMSIS devic data from NXP's LPCxxxx User Manuals
# Copyright (C) 2013  Richard Meadows
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.



# ========= Decoding Peripherals ========

$perhiperal_regex = /.*Register overview: (?<name>.*) \(base address:?(?<address>.*)/

$register_regex = /(?<name>(?:\w+)|\-)(?:\s)+(?<access>R\/W|R|W|WO|RO|\-)(?:\s)+(?<index>0x[0-9A-F]+)(?:\s)?(?:\-|to)?(?:\s)?(?:0x[0-9A-F]+)?(?:\s)+(?<description>(?:[\w\/\-]+)(?:\s[\w\/\-]+)*)(.*)/

# Returns a better default name for a perhiperal using the raw value
# from the datasheet
def get_perhiperal_default_name(raw_name)
  if bettermatch = /(?<better>[A-Z0-9]{3,})/.match(raw_name)
    return bettermatch[:better]
  end

  return raw_name
end
# Asks the user to name a perhiperal
def get_perhiperal_name(raw_name)
  default = get_perhiperal_default_name(raw_name)

  print "Name for \"#{raw_name}\" (Default #{default}): "; input = gets.strip
  input == '' ? default : input
end

# Parses all the registers in a table
def parse_registers(datasheet, registers)
  spaces = /(?<spaces>(?:\s)*)/.match(datasheet.gets)[:spaces].length

  while (line = datasheet.gets)
    without_spaces = line[spaces..-1]

    # If there is some content at the start of the line
    if without_spaces && without_spaces[0] != ' '
      if matchdata = $register_regex.match(without_spaces)
        # Regex Succeeded

        if matchdata[:name] != "-"
          index32 = Integer(matchdata[:index], 16)/4

          registers[index32] = {
            :name => matchdata[:name],
            :access => matchdata[:access],
            :description => matchdata[:description]
          }
        end

      else # Regex failed
        return registers # Go home
      end
    end
  end

end

# Parses all the registers for a perhiperal
def parse_perhiperal(datasheet, matchdata, perhiperals)
  if !perhiperals[matchdata[:name]] # New perhiperal
    perhiperals[matchdata[:name]] = {
      :raw_name => matchdata[:name],
      :name => get_perhiperal_name(matchdata[:name]),
      :address => matchdata[:address].gsub(/ /,''),
      :registers => parse_registers(datasheet, [])
    }
  else # Append to current perhiperal
    perhiperals[matchdata[:name]][:registers] =
      parse_registers(datasheet, perhiperals[matchdata[:name]][:registers])
  end

#  puts perhiperals[matchdata[:name]][:registers].inspect

  perhiperals
end

# ========= Encoding CMSIS ========

# Return the common prefix of an array of strings
def common_prefix(arr)
  return '' if !arr
  # We need only compare the first and last in alphabetical order
  first, last = arr.min, arr.max
  return '' if !first
  first.each_char.with_index do |char, i|
    return first[0...i] if char != last[i]
  end
end

# Return the string for the declaration of a perhiperal
def get_declaration(device, perip, address)
  p_name = "#{device}_#{perip}"

  "#define #{p_name}\t\t((#{p_name}_TypeDef*\t) #{address} )\n";
end
# Returns the macro for a register based on its access credentials
def get_access_label(register)
  case register[:access]
  when "RO", "R"
    "__I"
  when "WO", "W"
    "__O"
  else
    "__IO"
  end
end
# Returns the string for the declaration of a register
def get_register(register, common)
  access_label = get_access_label(register)
  name = register[:name]
  desc = register[:description]

  # Remove a common prefix if needed
  if common && common != ''
    name = name.split(common)[1]
  end

  "  #{access_label}\tuint32_t #{name};\t\t// #{desc}\n"
end
# Returns the string for the declaration of reserved value
def get_reserved(number, count)
  "\tuint32_t RESERVED#{number}[#{count}];\n"
end

# ========= Main ========

perhiperals = {};
device = "LPC"
full_device = "LPC11xx"

print "Datasheet to read: "; filename = gets.strip
puts

File.open(filename, "r") do |datasheet|
  while (line = datasheet.gets)
    # If this line is the start of a register overview table
    if matchdata = $perhiperal_regex.match(line)
      if !/(?:\)|ontinued)(?:\s)*$/.match(line) # If the title runs on to a new line
        datasheet.gets # Dump a line
      end
      perhiperals = parse_perhiperal(datasheet, matchdata, perhiperals);
    end
  end
end

File.open("cmsis_device.h", "w") do |cmsis|
  perhiperals.each do |raw_name, pr|

    name = pr[:name]

    cmsis.write "/*------------- #{raw_name} (#{name}) ----------------------------*/\n"
    cmsis.write "/** @addtogroup #{full_device}_#{name} #{full_device} #{raw_name} (#{name}) \n"
    cmsis.write "  @{\n"
    cmsis.write "*/\ntypedef struct\n{\n"

    # Determine the common prefix on the register names
    rnames = pr[:registers].select{ |reg| reg }.map { |reg| reg[:name] }
    common = common_prefix(rnames)

    res_count = 0
    rnumber = 0

    pr[:registers].each do |reg|
      if reg
	if res_count > 0
  	  cmsis.write get_reserved(rnumber, res_count)
          rnumber += 1
	  res_count = 0
	end

	cmsis.write get_register(reg, common)
      else
	res_count += 1
      end
    end

    cmsis.write "} #{device}_#{name}_TypeDef;\n"
    cmsis.write "/*@}*/ /* end of group #{full_device}_#{name} */\n\n"
  end

  cmsis.write "\n\n\n\n"

  perhiperals.each do |raw_name, pr|
    cmsis.write get_declaration("LPC", pr[:name], pr[:address])
  end

end

puts
puts "Look in cmsis_device.h to find C structs and macro definitions for CMSIS"
puts
