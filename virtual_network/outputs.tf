TODO: Här hade jag dragit in en kommentar så en icke programmera förstår vad som händer med key value for each loopen
output "subnet_ids" {
  value       = { for k, v in azurerm_subnet.this : k => v.id }
  // TODO: Description saknas, men ja de är tydligt för mig vad det här är för output
}


// TODO: Jag hade försökt lägga mer i outputs så man ser att allt blir korrekt i längre körningar, för att snabbt se fel samt som sanity checks när man gör saker på "jour timmarna"