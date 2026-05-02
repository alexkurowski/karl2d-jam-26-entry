text = <<~EOF
0 0 0        Black
29 43 83        DarkBlue
126 37 83        DarkPurple
0 135 81        DarkGreen
171 82 54        Brown
95 87 79        DarkGray
194 195 199        LightGray
255 241 232        White
255 0 77        Red
255 163 0        Orange
255 236 39        Yellow
0 228 54        Green
41 173 255        Blue
131 118 156        Lavender
255 119 168        Pink
255 204 170        LightPeach
EOF
out = []

text.lines.each_with_index do |line, index|
  parts = line.split(" ")
  r = parts[0].to_f
  g = parts[1].to_f
  b = parts[2].to_f
r = (r/ 255.0)
g = (g/ 255.0)
b = (b/ 255.0)
name = parts[3]
  out << "    vec3(#{"%.4f" % r}, #{"%.4f" % g}, #{"%.4f" % b}), // #{name}"
end

puts out.join("\n")
