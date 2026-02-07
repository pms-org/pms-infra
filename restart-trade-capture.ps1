# Restart trade-capture deployment
Write-Host "Restarting trade-capture deployment..." -ForegroundColor Yellow

# Delete the pod to force recreation with environment variables
kubectl delete pod -l app=trade-capture -n pms

Write-Host "Waiting for new pod to start..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=trade-capture -n pms --timeout=120s

Write-Host "`nChecking pod logs for Kafka connection..." -ForegroundColor Green
Start-Sleep -Seconds 5
kubectl logs -l app=trade-capture -n pms --tail=50 | Select-String -Pattern "kafka|localhost"
