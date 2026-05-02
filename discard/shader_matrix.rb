matrix = [
  [0,  4,  7,  4, 0],
  [4, 16, 26, 16, 4],
  [7, 26, 41, 26, 7],
  [4, 16, 26, 16, 4],
  [0,  4,  7,  4, 0],
]

sample_r = [
  [0, 1, 1, 0, 0],
  [1, 1, 1, 1, 0],
  [1, 1, 1, 1, 0],
  [1, 1, 1, 1, 0],
  [0, 1, 1, 0, 0],
]
sample_g = [
  [0, 0, 1, 0, 0],
  [0, 1, 1, 1, 0],
  [0, 1, 1, 1, 0],
  [0, 1, 1, 1, 0],
  [0, 0, 1, 0, 0],
]
sample_b = [
  [0, 0, 1, 1, 0],
  [0, 1, 1, 1, 1],
  [0, 1, 1, 1, 1],
  [0, 1, 1, 1, 1],
  [0, 0, 1, 1, 0],
]

total_r = 0
total_g = 0
total_b = 0
5.times do |x|
  5.times do |y|
    total_r += matrix[x][y] if sample_r[x][y] == 1
    total_g += matrix[x][y] if sample_g[x][y] == 1
    total_b += matrix[x][y] if sample_b[x][y] == 1
  end
end

out = []
out << "const float w3[] = float[]("
out << "  #{41.0 / total_g}, // 41"
out << "  #{26.0 / total_g}, // 26"
out << "  #{16.0 / total_g}, // 16"
out << "  #{7.0 / total_g}, // 7"
out << "  #{4.0 / total_g}); // 4"

out << "const float w1[] = float[]("
out << "  #{41.0 / total_r}, // 41"
out << "  #{26.0 / total_r}, // 26"
out << "  #{16.0 / total_r}, // 16"
out << "  #{7.0 / total_r}, // 7"
out << "  #{4.0 / total_r}); // 4"

puts out.join("\n")
