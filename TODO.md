# Próximas etapas

- [ ] Testar a interface da API com polígonos de bacias hidrográficas dos
  conjuntos [CABra](https://doi.org/10.5281/zenodo.4070146) e
  [CAMELS-BR](https://doi.org/10.5281/zenodo.3709337).

- [ ] Expandir os testes para as demais variáveis do
  [BR-DWGD](https://sites.google.com/site/alexandrecandidoxavierufes/brazilian-daily-weather-gridded-data):
  temperatura máxima (`Tmax`), temperatura mínima (`Tmin`), radiação solar
  (`Rs`), umidade relativa (`RH`) e velocidade do vento a 2 m (`u2`),
  preservando os códigos oficiais e definindo a agregação mensal adequada
  para cada variável.

- [ ] Aplicar o `extractmeteobr` aos dados de precipitação do
  [BRain-D](https://doi.org/10.5281/zenodo.15468235), com controle de qualidade,
  e avaliá-lo como alternativa para `pr`.

Estas tarefas são planejamento futuro; o suporte a esses conjuntos de dados
não foi validado.
