function Y = predict(m, n, X, Xs,Xv, piCell, xyCell, XrCell, expected)

res = cell(1, n);
if n==m.postSamN
	postSamInd = 1:n;
else
	postSamInd = randi([1, m.postSamN],1,n);
end

piN = nan(size(piCell));
piKeyN = cell(1, m.nr);
piMapN = cell(1, m.nr);
xy = cell(1, m.nr);
Xr = cell(1, m.nr);
for r=1:m.nr
	piKey = m.piKey{r};
	keySet = unique(piCell(:,r));
	exInd = m.piMap{r}.isKey(keySet);
	if any(~exInd)
		keySetN = keySet(~exInd);
		piKeyN{r} = [piKey; keySetN];
		newMap = containers.Map(keySetN, (length(piKey)+1):length(piKeyN{r}) );
		piMapN{r} = [m.piMap{r}; newMap];
	else
		piKeyN{r} = piKey;
		piMapN{r} =  m.piMap{r};
	end
	piN(:,r) = cell2mat(piMapN{r}.values( piCell(:,r)) );
	if m.spatial(r)
		piKey = piKeyN{r};
		xyKey = xyCell{r}(:,1);
		xyMap = containers.Map(xyKey,1:length(xyKey));
		if ~all(xyMap.isKey(piKey))
			error('HMSC: some units, defined at level %d were not given spatial coordinates\n', r);
		end
		ind = cell2mat( xyMap.values(piKey) );
		xy1 = xyCell{r}(ind, 2:size(xyCell{r}, 2));
		xy1 = cell2mat(xy1);
		xy{r} = xy1;
	end
	if m.factorCov(r)
		piKey = piKeyN{r};
		XrKey = XrCell{r}(:,1);
		XrMap = containers.Map(XrKey,1:length(XrKey));
		if ~all(XrMap.isKey(piKey))
			error('HMSC: some units, defined at level %d were not given factor covariates\n', r);
		end
		ind = cell2mat( XrMap.values(piKey) );
		Xr1 = XrCell{r}(ind, 2:size(XrCell{r}, 2));
		Xr1 = cell2mat(Xr1);
		Xr{r} = Xr1;
	end
end
pi = piN;

diaa = cell(1, m.nr);
diss = cell(1, m.nr);
dias = cell(1, m.nr);
LiFgA = cell(1, m.nr);
W21iDW12gA = cell(1, m.nr);
WssgA = cell(1, m.nr);
iWssgA = cell(1, m.nr);
WnoiWoogA = cell(1, m.nr);
LWNgA = cell(1, m.nr);
WnsgA = cell(1, m.nr);
WnsiWssgA = cell(1, m.nr);
dDngA = cell(1, m.nr);
BgA = cell(1, m.nr);
FgA = cell(1, m.nr);
alphaAllPost = cat(1,m.postSamVec(postSamInd).alpha);
for r = 1:m.nr
	newPiInd = ~ismember(pi(:,r), m.pi(:,r));
	pi1 = pi(newPiInd, r);
	newPiN = length(unique(pi1));
	np = m.np(r);
	if m.spatial(r) && newPiN > 0
		xy1 = xy{r};
		alphapw = m.alphapw{r};
		alphagN = size(alphapw, 1);
		alphaIndUn = sort(unique(cell2mat(alphaAllPost(:,r))));
		switch m.spatialMethod{r}
			case 'GP'
				daa = zeros(m.np(r)+newPiN);
				for j = 1:m.spatDim(r)
					xx = repmat(xy1(:,j), 1, m.np(r)+newPiN);
					dx = xx-xx';
					daa = daa+dx.^2;
				end
				daa = sqrt(daa);
				diaa{r} = daa;
				
				WnoiWoog = cell(1, alphagN);
				LWNg = cell(1, alphagN);
				don = daa(1:m.np(r), m.np(r)+(1:newPiN));
				dnn = daa(m.np(r)+(1:newPiN), m.np(r)+(1:newPiN));
				for i = 1:length(alphaIndUn)
					ag = alphaIndUn(i);
					alpha = alphapw(ag,1);
					if alpha > 0
						Won = exp(-don/alpha);
						Wnn = exp(-dnn/alpha);
					else
						Won = zeros(size(don));
						Wnn = eye(size(dnn));
					end
					iWooR = m.iWgR{r}(:,:,ag);
					WnoiWooR = Won' * iWooR';
					WN = Wnn - WnoiWooR * WnoiWooR';
					WnoiWoog{ag} = WnoiWooR * iWooR;
					LWNg{ag} = chol(WN,'lower');
				end
				WnoiWoogA{r} = WnoiWoog;
				LWNgA{r} = LWNg;
			case 'PGP'
				xys = m.xyKnot{r};
				dss = zeros(size(xys,1));
				for j = 1:m.spatDim(r)
					xx = repmat(xys(:,j), 1, size(xys,1));
					dx = xx-xx';
					dss = dss+dx.^2;
				end
				das = zeros(size(xy1,1),size(xys,1));
				for j = 1:m.spatDim(r)
					xx2 = repmat(xys(:,j), 1, size(xy1,1));
					xx1 = repmat(xy1(:,j), 1, size(xys,1));
					dx = xx1-xx2';
					das = das+dx.^2;
				end
				dss = sqrt(dss);
				das = sqrt(das);
				dns = das(m.np(r)+(1:newPiN),:);
				diss{r} = dss;
				dias{r} = das;
				
				LiFgA{r} = cholx_mex(m.iFg{r});
				WssgA{r} = cell(1,size(m.alphapw{r},1));
				iWssgA{r} = cell(1,size(m.alphapw{r},1));
				WnsgA{r} = cell(1,size(m.alphapw{r},1));
				WnsiWssgA{r} = cell(1,size(m.alphapw{r},1));
				dDngA{r} = cell(1,size(m.alphapw{r},1));
				for i = 1:length(alphaIndUn)
					ag = alphaIndUn(i);
					alpha = m.alphapw{r}(ag,1);
					if alpha > 0
						WnsgA{r}{ag} = exp(-dns/alpha);
						WssgA{r}{ag} = exp(-dss/alpha);
						iWssgA{r}{ag} = invChol_mex(WssgA{r}{ag});
						Wns = exp(-dns/alpha);
						WnsiWss = WnsgA{r}{ag}*iWssgA{r}{ag};
% 						WnsiWssgA{r}{ag} = WnsgA{r}{ag}*iWssgA{r}{ag};
						dDngA{r}{ag} = ones(size(Wns,1),1) - sum(WnsiWss.*Wns,2);
					else
						WnsgA{r}{ag} = zeros(size(dns));
						WssgA{r}{ag} = eye(size(dss));
						iWssgA{r}{ag} = eye(size(dss));
						dDngA{r}{ag} = ones(size(dns,1),1);
					end
				end
			case 'NNGP'
				nnN = m.nnNumber(r);
				xyN = xy1((np+1):end,:);
				xyO = xy1(1:np,:);
				indNN = knnsearch(xyO,xyN,'K',nnN);
				indices = cell(2,newPiN);
				dist12 = nan(nnN,newPiN);
				dist11 = nan(nnN,nnN,newPiN);
				for i = 1:newPiN
					ind = indNN(i,:);
					indices{1,i} = repmat(i,[1,nnN]);
					indices{2,i} = ind;
					dist12(:,i) = sqrt(sum((xyO(ind,:)-repmat(xyN(i,:),[nnN,1])).^2,2));
					dist11(:,:,i) = squareform(pdist(xyO(ind,:)));
				end
				
				BgA{r} = cell(1,alphagN);
				FgA{r} = cell(1,alphagN);
				for i = 1:length(alphaIndUn)
					ag = alphaIndUn(i);
					alpha = m.alphapw{r}(ag,1);
					if alpha > 0
						K12 = exp(-dist12/alpha);
						ind1 = cat(2,indices{2,:});
						ind2 = cat(2,indices{1,:});
						K11 = exp(-dist11/alpha);
						iK11 = invCholx_mex(K11);
						
						K21iK11 = mtimesx(permute(K12,[3,1,2]),iK11);
						B = sparse(ind2,ind1,K21iK11(:),newPiN,np);
						F = 1-sum(permute(K21iK11,[2,3,1]).*K12,1);
% 						F = nan(1,newPiN);
% 						for i = 1:newPiN
% 							F(i) = 1 - K12(:,i)'*inv(K11(:,:,i))*K12(:,i);
% 						end
						BgA{r}{ag} = B;
						FgA{r}{ag} = F;
					else
						BgA{r}{ag} = sparse(np,newPiN);
						FgA{r}{ag} = ones(1,newPiN);
					end
				end
		end
	end
end

for rN = 1:n
	if mod(rN, 100) == 0
		fprintf('Calculating prediction %d\n', rN);
	end
	p = m.postSamVec(postSamInd(rN));
	if m.speciesX
		ny = size(X{1}, 1);
		Ez = zeros(ny, m.ns);
		for j = 1:m.ns
			Ez(:,j) = X{j}*p.beta(:,j);
		end
	else
		ny = size(X, 1);
		Ez = X*p.beta;
	end
	
	for r = 1:m.nr
		etaM = p.eta{r};
		lambda1 = p.lambda{r};
		newPiInd = ~ismember(pi(:,r), m.pi(:,r));
		pi1 = pi(newPiInd, r);
		newPiN = length( unique(pi1) );
		if m.spatial(r) && newPiN > 0
			alphaInd = p.alpha{r};
			alphapw = m.alphapw{r};
			etaN = nan(newPiN, p.nf(r));
			for j = 1:p.nf(r)
				ag = alphaInd(j);
				alpha = alphapw(ag, 1);
				if alpha > 0
					switch m.spatialMethod{r}
						case 'GP'
							WnoiWoo = WnoiWoogA{r}{ag};
							LWN = LWNgA{r}{ag};
							muN = WnoiWoo * etaM(:,j);
							etaN(:,j) = muN + LWN*randn(newPiN,1);
						case 'PGP'
							% dss = diss{r};
							Wss = WssgA{r}{ag};
							Wns = WnsgA{r}{ag};
							dDn = dDngA{r}{ag};
							iF = m.iFg{r}(:,:,ag);
							idDW12 = m.idDW12g{r}(:,:,ag);
							LiF = LiFgA{r}(:,:,ag);
							
							muS1 = iF*idDW12'*etaM(:,j);
							epsS1 = LiF*randn(size(Wss,1),1);
							muN = Wns*(muS1+epsS1);
							etaN(:,j) = muN + sqrt(dDn).*randn(newPiN,1);
							
							%                                 iWss = iWssgA{r}{ag};
							%                                 F = m.Fg{r}(:,:,ag);
							%                                 tmp1 = idDW12'*etaM(:,j);
							%                                 tmp2 = F-Wss;
							%                                 muS = tmp1 - (tmp2)*(iF*tmp1);
							%                                 SigSS = Wss - tmp2 + tmp2*iF*tmp2;
							%                                 LSigSS = chol(SigSS);
							%                                 etaN(:,j) = Wns*(iWss*(muS+LSigSS*randn(size(Wss,1),1))) + sqrt(dDn).*randn(newPiN,1);
						case 'NNGP'
							muN = BgA{r}{ag}*etaM(:,j);
							etaN(:,j) = muN + sqrt(FgA{r}{ag})'.*randn(newPiN,1);
					end
				else
					etaN(:,j) = normrnd(0,1,[newPiN,1]);
				end
			end
		else
			etaN = normrnd(0,1,[newPiN,p.nf(r)]);
		end
		eta = [etaM; etaN];
		if m.factorCov(r)
			for k = 1:m.ncr(r)
				Xreta = repmat(Xr{r}(:,k), 1, p.nf(r)).*eta;
				Ez = Ez + Xreta(pi(:,r),:)*lambda1(:,:,k);
			end
		else
			Ez = Ez + eta(pi(:,r),:)*lambda1;
		end
	end
	
	if m.includeXs
		Xel = Xs*p.etas*p.lambdas;
		Ez = Ez+Xel;
	end
	if m.includeXv
		Xel = Xv*(p.qv.*p.betav);
		Ez = Ez+Xel;
	end
	
	z = Ez;
	if expected == false
		
		eps = normrnd(zeros(ny, m.ns), 1);
		eps = eps .* repmat(diag(p.sigma)', ny, 1);
		%eps = zeros(ny, m.ns);
		%for i = 1:ny
		%   eps(i,:) = normrnd(zeros(1,m.ns), diag(p.sigma)' );
		%end
		mult=ones(ny, m.ns);
		for j = 1:m.ns
			if m.dist(j,3) == 1
				mult(:,j) = max(Ez(:,j),1).^m.dist(j,4);
			end
			if m.dist(j,3) == 2
				mult(:,j) = exp(Ez(:,j)).^m.dist(j,4);
			end
		end
		z = z + mult.*eps;
	end
	Y = z;
	
	for j = 1:m.ns
		if(m.dist(j,1) == 2)
			if expected
				Y(:,j) = normcdf(z(:,j));
			else
				Y(:,j) = z(:,j)>0;
			end
		end
		if(m.dist(j,1) == 3)
			if expected
				Y(:,j) = exp(z(:,j));
			else
				Y(:,j) = poissrnd(exp(z(:,j)));
			end
		end
		if(m.dist(j,1) == 4)
			if expected
				Y(:,j) = max(0,z(:,j));
			else
				Y(:,j) = max(0,z(:,j));
			end
			Y(:,j) = poissrnd(max(0,z(:,j)));
		end
	end
	res{rN} = Y;
end
Y = res;

end



% muN1 = (m.idDg{r}(:,ag).*etaM(:,j));
% muN2 = m.idDW12g{r}(:,:,ag)*( m.iFg{r}(:,:,ag)*(m.idDW12g{r}(:,:,ag)'*etaM(:,j)) );
% muN = Won'*(muN1-muN2);
% tmp = Won'*m.idDW12g{r}(:,:,ag);
% tmp2 = Wnn - Won'*diag(m.idDg{r}(:,ag))*Won + tmp*m.iFg{r}(:,:,ag)*tmp';
% tmp2 = (tmp2+tmp2')/2;
% eigMin = min(eig(tmp2));
% if eigMin < 0
%    addVal = -eigMin*(1+0.001);
% elseif eigMin == 0
%    addVal = 0.001;
% else
%    addVal = 0;
% end
% tmp2 = tmp2 + (addVal)*eye(newPiN);