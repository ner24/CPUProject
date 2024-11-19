/* generated with ChatGPT*/
#include <iostream>
#include <vector>
#include <cmath>
#include <cstdlib>
#include <ctime>
#include <limits>
#include <algorithm>
#include <random>

using namespace std;

namespace travelling_salesman {
  struct City {
      int x, y;
  };

  double calculateDistance(const City& a, const City& b) {
      return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2));
  }

  double calculateTotalDistance(const vector<City>& cities, const vector<int>& path) {
      double totalDistance = 0;
      for (size_t i = 0; i < path.size(); ++i) {
          totalDistance += calculateDistance(cities[path[i]], cities[path[(i + 1) % path.size()]]);
      }
      return totalDistance;
  }

  vector<int> generateNeighbor(const vector<int>& path) {
      vector<int> neighbor = path;
      int idx1 = rand() % neighbor.size();
      int idx2 = rand() % neighbor.size();
      swap(neighbor[idx1], neighbor[idx2]);
      return neighbor;
  }

  double simulatedAnnealing(const vector<City>& cities, double initialTemp, double coolingRate) {
      int n = cities.size();
      vector<int> currentPath(n);
      vector<int> bestPath(n);

      for (int i = 0; i < n; ++i) {
          currentPath[i] = i;
      }
      random_device rd;
      mt19937 g(rd());
      shuffle(currentPath.begin(), currentPath.end(), g);
      //random_shuffle(currentPath.begin(), currentPath.end());
      bestPath = currentPath;

      double bestDistance = calculateTotalDistance(cities, bestPath);
      double currentDistance = bestDistance;

      double temperature = initialTemp;

      while (temperature > 1) {
          vector<int> newPath = generateNeighbor(currentPath);
          double newDistance = calculateTotalDistance(cities, newPath);

          if (newDistance < currentDistance || 
              (exp((currentDistance - newDistance) / temperature) > ((double) rand() / RAND_MAX))) {
              currentPath = newPath;
              currentDistance = newDistance;

              if (currentDistance < bestDistance) {
                  bestDistance = currentDistance;
                  bestPath = currentPath;
              }
          }

          temperature *= coolingRate;
      }

      return bestDistance;
  }

  int starting_point() {
      srand(static_cast<unsigned>(time(0)));

      int n;
      cout << "Enter the number of cities: ";
      cin >> n;

      vector<City> cities(n);
      cout << "Enter the coordinates of the cities (x y):\n";
      for (int i = 0; i < n; ++i) {
          cin >> cities[i].x >> cities[i].y;
      }

      double initialTemp = 1000;
      double coolingRate = 0.995;

      double minDistance = simulatedAnnealing(cities, initialTemp, coolingRate);

      cout << "Minimum distance: " << minDistance << endl;

      return 0;
  }
}
