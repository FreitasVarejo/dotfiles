# Dotfiles                                                                                                                                                                            
                                                                                                                                                                                        
### Minhas configurações personalizadas de terminal, que transporto entre máquinas diferentes                                                                                         
                                                                                                                                                                                        
- **Neovim**: Configuração modular (LSP, Treesitter, Mason, CMP).                                                                                                                       
- **Tmux**: Otimizado para Neovim, suporte a True Color e tema Dracula.                                                                                                                 
- **Bash**: Configurações de ambiente e aliases.                                                                                                                                        
- **Git**: Configurações globais básicas.                                                                                                                                               
                                                                                                                                                                                        
### Como Instalar                                                                                                                                                                        
Para aplicar estas configurações em uma nova máquina:                                                                                                                                   
  
```bash                                                                                                                                                                                 
git clone https://github.com/FreitasVarejo/dotfiles.git ~/dotfiles                                                                                                                        
cd ~/dotfiles                                                                                                                                                                           
chmod +x install.sh                                                                                                                                                                     
./install.sh                             
```                                                                                                                                               
                                                                                                                                                                                             
> Aviso: O script install.sh criará backups automáticos de suas configurações atuais em uma pasta ~/dotfiles_old_... antes de criar os links simbólicos.
