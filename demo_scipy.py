from scipy.stats import beta
from json import dumps

print(dumps(list(beta.ppf([0.2, 0.5, 0.7], 1, 1))))
